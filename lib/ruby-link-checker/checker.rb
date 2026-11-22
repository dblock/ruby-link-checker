# frozen_string_literal: true

module LinkChecker
  class Checker
    include LinkChecker::Config
    include LinkChecker::Callbacks

    # Events published once per link with its final result.
    OUTCOME_EVENTS = %i[error failure success blocked].freeze

    # Settings that do not change the request or response, excluded from request identity.
    IDENTITY_EXCLUDED_ATTRIBUTES = %i[
      logger cache deduplicate blocked_status_codes detect_challenges max_concurrency_per_host min_host_interval
      rate_limit_retries rate_limit_status_codes rate_limit_backoff max_rate_limit_delay
    ].freeze

    attr_reader :results

    def initialize(options = {})
      LinkChecker::Config::ATTRIBUTES.each do |key|
        send("#{key}=", options.fetch(key) { LinkChecker.config.send(key) })
      end
      raise ArgumentError, "Missing methods." if methods&.none?
      @logger ||= options[:logger] || LinkChecker::Config.logger || LinkChecker::Logger.default
      @results = { error: [], failure: [], success: [], blocked: [] } unless options.key?(:results) && !options[:results]
      @pending = {}
      @successful = {}
      @host_next_start = {}
      @host_backoff = Hash.new(0)
      @cache_store = Cache.new(cache, logger: @logger) if cache
    end

    def task_klass
      @task_klass ||= begin
        module_name = self.class.name.split("::")[...-1].join('::')
        Object.const_get("#{module_name}::Task")
      end
    end

    def check(uri, options = {})
      return execute_check(uri, options) unless deduplicate || @cache_store

      key = request_key(uri)
      return execute_check(uri, options) unless key

      subscriber = [uri.to_s.dup, options]
      if deduplicate && (entry = @pending[key])
        entry[:subscribers] << subscriber
        entry[:events].each { |event, result| publish(event, copy_result(result, subscriber)) }
        return
      end

      cached_result = @successful[key] if deduplicate
      cached_result ||= @cache_store&.fetch(key, uri)
      if cached_result&.success?
        @successful[key] ||= cached_result if deduplicate
        return publish_cached(:success, cached_result, subscriber)
      end
      return publish_cached(:blocked, cached_result, subscriber) if blocked_result?(cached_result)

      entry = { subscribers: [subscriber], events: [] }
      @pending[key] = entry if deduplicate
      execute_check(uri, options) { |event, result| handle_shared_result(key, entry, uri, event, result) }
    end

    # Finishes a run. Checkers that queue requests run them first; Net::HTTP checks links as they are submitted.
    def run
      _finish_run
    end

    # Removes cache entries that this checker did not use, returning the number of entries removed.
    def prune_cache!
      @cache_store ? @cache_store.prune! : 0
    end

    # Whether a final, non-successful HTTP result should be reported as blocked rather than failed.
    def blocked_result?(result)
      return false if result.nil? || result.error? || result.success? || result.redirect?
      return true if blocked_status_codes.include?(result.code)

      detect_challenges && result.challenge?
    end

    # Request headers for uri: the user-agent, then global headers, then every matching host_headers entry.
    # Later values replace earlier ones with the same case-insensitive name.
    def request_headers_for(uri)
      _merge_headers([{ 'User-Agent' => user_agent }, headers] + _matching_host_headers(uri))
    end

    # The host that per-host limits apply to, or nil when the URI has none.
    def _host_key(uri)
      URI(uri.to_s).host&.downcase
    rescue URI::InvalidURIError
      nil
    end

    # Seconds to wait before the next request to host may start, without reserving it.
    def _host_wait(host)
      return 0 unless host && @host_next_start[host]

      [@host_next_start[host] - _monotonic_time, 0].max
    end

    # Reserves the next start for host, spaced by min_host_interval, and returns the seconds to wait for it.
    def _reserve_host_slot(host)
      return 0 unless host

      wait = _host_wait(host)
      @host_next_start[host] = _monotonic_time + wait + min_host_interval if min_host_interval.positive?
      wait
    end

    # Whether a response should be retried with per-host rate limit backoff.
    def rate_limited?(result)
      rate_limit_retries.positive? && !result.error? && rate_limit_status_codes.include?(result.code)
    end

    # Pauses every request to host after a rate limited result and returns the pause in seconds.
    # The pause doubles with each rate limited response from host, starting at rate_limit_backoff,
    # but rate limited responses that arrive while host is already paused don't escalate it.
    # Retry-After is honored as a minimum, and every pause is capped at max_rate_limit_delay.
    def _rate_limit!(host, result)
      return 0 unless host

      @host_backoff[host] += 1 unless _host_wait(host).positive? && @host_backoff[host].positive?
      delay = rate_limit_backoff * (2**(@host_backoff[host] - 1))
      delay = [delay, result.retry_after_delay].max
      delay = [delay, max_rate_limit_delay].min
      @host_next_start[host] = [@host_next_start[host] || 0, _monotonic_time + delay].max
      logger.info "Rate limited by #{host}, pausing requests for #{delay.round(2)}s"
      delay
    end

    # Resets the backoff of host after a response that isn't rate limited.
    def _rate_limit_reset!(host)
      @host_backoff.delete(host) if host
    end

    private

    def _finish_run
      prune_cache! if @cache_store&.prune?
    end

    # The host_headers values that apply to uri, in configuration order.
    def _matching_host_headers(uri)
      host = _host_key(uri)
      return [] unless host

      host_headers.filter_map { |pattern, values| values if _host_match?(pattern, host) }
    end

    # Merges header hashes in order; later values replace earlier ones with the same case-insensitive name.
    def _merge_headers(sources)
      sources.each_with_object({}) do |values, merged|
        values.each do |name, value|
          merged.delete_if { |existing, _value| existing.casecmp?(name.to_s) }
          merged[name.to_s] = value
        end
      end
    end

    def _host_match?(pattern, host)
      pattern.is_a?(Regexp) ? pattern.match?(host) : pattern == host
    end

    def _monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def execute_check(uri, options, &handler)
      tasks = Tasks.new(
        self,
        task_klass,
        uri,
        methods,
        options
      )
      tasks.on do |event, *args|
        handler ? handler.call(event, *args) : publish(event, args.first)
      end
      tasks.execute!
    end

    def publish_cached(event, cached_result, subscriber)
      result = copy_result(cached_result, subscriber)
      result.cached = true
      result.blocked = event == :blocked
      publish(:result, result)
      publish(event, result)
    end

    def publish(event, result)
      result.checker = self
      outcome = OUTCOME_EVENTS.include?(event)
      results[event] << result if @results && outcome
      callback(event, result)
      callback(:complete, result) if outcome
    end

    def handle_shared_result(key, entry, uri, event, result)
      entry[:events] << [event, result]
      subscribers = entry[:subscribers].dup
      if OUTCOME_EVENTS.include?(event)
        @pending.delete(key) if @pending[key].equal?(entry)
        if %i[success blocked].include?(event) && request_key(uri) == key
          @successful[key] = result if deduplicate && event == :success
          @cache_store&.store(key, result)
        end
      end
      subscribers.each { |subscriber| publish(event, copy_result(result, subscriber)) }
    end

    def copy_result(result, subscriber)
      result.dup.tap do |copy|
        copy.uri = URI(subscriber.first)
        # Without redirects, the final URL is the submitted one, including its own fragment.
        copy.result_uri = result.redirects.empty? ? URI(subscriber.first) : result.result_uri.dup
        copy.options = subscriber.last
      end
    end

    def request_key(uri)
      parsed = URI(uri.to_s)
      return unless %w[http https].include?(parsed.scheme) && parsed.host && !parsed.userinfo

      # Fragments are never sent over HTTP, so links that differ only by #fragment share a check.
      parsed.fragment = nil

      attributes = Config::ATTRIBUTES - IDENTITY_EXCLUDED_ATTRIBUTES
      attributes += %i[timeout connecttimeout read_timeout open_timeout protocol].select { |key| respond_to?(key) }
      settings = attributes.to_h { |key| [key, send(key)] }
      # Only the headers sent for this URL are part of its identity, so changing the headers of other hosts keeps it.
      settings[:headers] = _merge_headers([headers] + _matching_host_headers(parsed)).sort_by { |key, _value| key }
      settings.delete(:host_headers)
      Digest::SHA256.hexdigest(JSON.generate([task_klass.name, parsed.to_s, settings]))
    rescue URI::InvalidURIError, JSON::GeneratorError, TypeError
      nil
    end
  end
end
