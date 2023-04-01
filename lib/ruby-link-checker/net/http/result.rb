module LinkChecker
  module Net
    module HTTP
      class Result < ::LinkChecker::Result
        attr_accessor :request, :response

        def initialize(uri, method, request, response, options)
          @request = request
          @response = response
          super uri, method, options
        end

        def error?
          false
        end

        def failure?
          !success? && !redirect?
        end

        def code
          @code ||= begin
            response.code.to_i
          rescue StandardError
            -1
          end
        end

        def request_headers
          request
        end

        def redirect_to
          return nil unless response

          response['Location']
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
