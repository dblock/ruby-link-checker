module LinkChecker
  module Net
    class HTTP
      class Result < ::LinkChecker::Result
        attr_accessor :request, :response

        def initialize(uri, request, response)
          @request = request
          @response = response
          super uri
        end

        def error?
          false
        end

        def failure?
          !success?
        end

        def success?
          return false unless response

          code = begin
            response.code.to_i
          rescue StandardError
            -1
          end
          code >= 200 && code <= 299
        end
      end
    end
  end
end
