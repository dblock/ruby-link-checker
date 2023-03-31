module LinkChecker
  module Typhoeus
    module Hydra
      class Task < ::LinkChecker::Task
        def run!
          request = ::Typhoeus::Request.new(uri, method: method, followlocation: false)
          request.on_complete do |response|
            logger.debug "#{method} #{uri}: #{response.code}"
            result! Result.new(uri, method, request, response)
          end
          options[:checker]._queue(request)
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