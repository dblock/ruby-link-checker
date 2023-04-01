module LinkChecker
  module Typhoeus
    module Hydra
      class Task < ::LinkChecker::Task
        def run!
          request = ::Typhoeus::Request.new(
            uri, {
              method: method,
              followlocation: false,
              headers: {
                'User-Agent' => checker.user_agent
              }
            }
          )
          request.on_complete do |response|
            if response.timed_out?
              logger.debug "#{method} #{uri}: #{response.return_code}"
              result! ResultError.new(uri, method, TimeoutError.new, options)
            else
              logger.debug "#{method} #{uri}: #{response.code}"
              result! Result.new(uri, method, request, response, options)
            end
          end
          checker._queue(request)
        end
      end

      class Checker < LinkChecker::Checker
        def initialize(options = {})
          super options
          @hydra = ::Typhoeus::Hydra.new(options[:hydra] || { max_concurrency: 10 })
        end

        def run
          @hydra.run
        end

        def _queue(request)
          @hydra.queue(request)
        end
      end
    end
  end
end
