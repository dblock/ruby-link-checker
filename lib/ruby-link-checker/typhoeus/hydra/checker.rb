module LinkChecker
  module Typhoeus
    module Hydra
      class Task < ::LinkChecker::Task
        def run!
          request = ::Typhoeus::Request.new(
            uri, {
              method: method,
              followlocation: false,
              timeout: checker.timeout,
              connecttimeout: checker.connecttimeout,
              headers: {
                'User-Agent' => checker.user_agent
              }
            }
          )
          request.on_complete do |response|
            if response.timed_out?
              logger.debug "#{method} #{uri}: #{response.return_code}"
              result! ResultError.new(uri, method, Timeout::Error.new, options)
            else
              logger.debug "#{method} #{uri}: #{response.code}"
              result! Result.new(uri, method, request, response, options)
            end
          end
          checker._queue(request)
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
          super options
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
