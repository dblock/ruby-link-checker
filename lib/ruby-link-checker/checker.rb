# frozen_string_literal: true

module LinkChecker
  class Checker
    include LinkChecker::Config
    include LinkChecker::Callbacks

    # Events published once per link with its final result.
    OUTCOME_EVENTS = %i[error failure success blocked].freeze

    # Settings that do not change the request or response, excluded from request identity.
    IDENTITY_EXCLUDED_ATTRIBUTES = %i[logger cache deduplicate blocked_status_codes detect_challenges].freeze

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
      if cached_result
        @successful[key] ||= cached_result if deduplicate
        result = copy_result(cached_result, subscriber)
        result.cached = true
        publish(:result, result)
        publish(:success, result)
        return
      end

      entry = { subscribers: [subscriber], events: [] }
      @pending[key] = entry if deduplicate
      execute_check(uri, options) { |event, result| handle_shared_result(key, entry, uri, event, result) }
    end

    # Whether a final, non-successful HTTP result should be reported as blocked rather than failed.
    def blocked_result?(result)
      return false if result.nil? || result.error? || result.success? || result.redirect?
      return true if blocked_status_codes.include?(result.code)

      detect_challenges && challenge?(result)
    end

    private

    # Cloudflare sets cf-mitigated: challenge on every challenge page.
    # https://developers.cloudflare.com/cloudflare-challenges/challenge-types/challenge-pages/detect-response/
    def challenge?(result)
      Array(result.response_headers['cf-mitigated']).join(',').split(',').map(&:strip).include?('challenge')
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

    def publish(event, result)
      result.checker = self
      results[event] << result if @results && OUTCOME_EVENTS.include?(event)
      callback(event, result)
    end

    def handle_shared_result(key, entry, uri, event, result)
      entry[:events] << [event, result]
      subscribers = entry[:subscribers].dup
      if OUTCOME_EVENTS.include?(event)
        @pending.delete(key) if @pending[key].equal?(entry)
        if event == :success && request_key(uri) == key
          @successful[key] = result if deduplicate
          @cache_store&.store(key, result)
        end
      end
      subscribers.each { |subscriber| publish(event, copy_result(result, subscriber)) }
    end

    def copy_result(result, subscriber)
      result.dup.tap do |copy|
        copy.uri = URI(subscriber.first)
        copy.result_uri = result.result_uri.dup
        copy.options = subscriber.last
      end
    end

    def request_key(uri)
      parsed = URI(uri.to_s)
      return unless %w[http https].include?(parsed.scheme) && parsed.host && !parsed.userinfo

      attributes = Config::ATTRIBUTES - IDENTITY_EXCLUDED_ATTRIBUTES
      attributes += %i[timeout connecttimeout read_timeout open_timeout protocol].select { |key| respond_to?(key) }
      settings = attributes.to_h { |key| [key, send(key)] }
      settings[:headers] = headers.sort_by { |key, _value| key.to_s }
      Digest::SHA256.hexdigest(JSON.generate([task_klass.name, parsed.to_s, settings]))
    rescue URI::InvalidURIError, JSON::GeneratorError, TypeError
      nil
    end
  end
end
