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
          super options
        end

        def run
          loop do
            @hydra.run
            break if @delayed.empty?

            deadline = @delayed.map(&:first).min
            sleep([deadline - monotonic_time, 0].max)
            ready, @delayed = @delayed.partition { |time, _request| time <= monotonic_time }
            ready.each { |entry| @hydra.queue(entry.last) }
          end
        end

        def _queue(request, delay: 0)
          if delay.positive?
            @delayed << [monotonic_time + delay, request]
          else
            @hydra.queue(request)
          end
        end

        private

        def monotonic_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
