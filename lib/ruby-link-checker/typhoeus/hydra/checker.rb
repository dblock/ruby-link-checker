module LinkChecker
  module Typhoeus
    module Hydra
      class Task < ::LinkChecker::Task
        def run!
          request = ::Typhoeus::Request.new(
            uri, {
              method: method.downcase.to_sym,
              followlocation: false,
              timeout: checker.timeout,
              connecttimeout: checker.connecttimeout,
              headers: {
                'User-Agent' => checker.user_agent
              }.merge(checker.headers)
            }
          )
          request.on_complete do |response|
            if response.timed_out?
              result! ResultError.new(uri, method, original_uri, Timeout::Error.new, options)
            elsif response.code.zero?
              error = LinkChecker::Errors::ConnectionError.new(response.return_code, response.return_message)
              result! ResultError.new(uri, method, original_uri, error, options)
            else
              result! Result.new(uri, method, original_uri, request, response, options)
            end
          end
          checker._queue(request, delay: delay)
        end
      end

      class Checker < LinkChecker::Checker
        extend ::LinkChecker::Typhoeus::Hydra::Config

        attr_accessor(*LinkChecker::Typhoeus::Hydra::Config::ATTRIBUTES)

        def initialize(options = {})
          LinkChecker::Typhoeus::Hydra::Config::ATTRIBUTES.each do |key|
            send("#{key}=", options[key] || LinkChecker::Typhoeus::Hydra::Config.send(key))
          end
          @hydra = ::Typhoeus::Hydra.new(options[:hydra] || { max_concurrency: 10 })
          @delayed = []
          @host_waiting = Hash.new { |hash, host| hash[host] = [] }
          @host_active = Hash.new(0)
          @host_scheduled = {}
          super options
        end

        def run
          loop do
            @hydra.run
            break if @delayed.empty?

            deadline = @delayed.map(&:first).min
            sleep([deadline - _monotonic_time, 0].max)
            ready, @delayed = @delayed.partition { |time, _action| time <= _monotonic_time }
            ready.each { |entry| entry.last.call }
          end
        end

        def _queue(request, delay: 0)
          if delay.positive?
            @delayed << [_monotonic_time + delay, -> { _admit(request) }]
          else
            _admit(request)
          end
        end

        private

        def _host_limits?
          max_concurrency_per_host || min_host_interval.positive?
        end

        # Holds requests per host and hands them to Hydra within the per-host limits.
        def _admit(request)
          host = _host_key(request.base_url)
          return @hydra.queue(request) unless host && _host_limits?

          @host_waiting[host] << request
          _dispatch(host)
        end

        def _dispatch(host)
          waiting = @host_waiting[host]
          while waiting.any?
            return if max_concurrency_per_host && @host_active[host] >= max_concurrency_per_host

            wait = _host_wait(host)
            return _schedule_dispatch(host, wait) if wait.positive?

            request = waiting.shift
            _reserve_host_slot(host)
            @host_active[host] += 1
            request.on_complete do
              @host_active[host] -= 1
              _dispatch(host)
            end
            @hydra.queue(request)
          end
        end

        # Hydra cannot start a request later, so retry the dispatch once the active batch drains.
        def _schedule_dispatch(host, wait)
          return if @host_scheduled[host]

          @host_scheduled[host] = true
          @delayed << [_monotonic_time + wait, lambda {
            @host_scheduled.delete(host)
            _dispatch(host)
          }]
        end
      end
    end
  end
end
