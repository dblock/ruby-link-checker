module LinkChecker
  module Typhoeus
    module Hydra
      class Result < ::LinkChecker::Result
        attr_accessor :request, :response

        def initialize(uri, method, original_uri, request, response, options)
          @request = request
          @response = response
          super uri, method, original_uri, options
        end

        def error?
          false
        end

        def failure?
          !success? && !redirect? && !error?
        end

        def code
          @code ||= begin
            response.code.to_i
          rescue StandardError
            -1
          end
        end

        def request_headers
          request.options[:headers]
        end

        def redirect_to
          return nil unless response

          response.headers['Location']
        end

        def redirect?
          return false unless response

          [301, 302, 303, 307, 308].include?(code)
        end

        def success?
          return false unless response

          code >= 200 && code <= 299
        end
      end
    end
  end
end
