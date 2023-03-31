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
          options[:checker].hydra.tap do |hydra|
            hydra.queue(request)
          end
        end
      end

      class Checker < LinkChecker::Checker
        attr_reader :hydra

        def initialize(options = {})
          super options
          @hydra = ::Typhoeus::Hydra.new(options[:hydra] || {})
        end
      end
    end
  end
end
