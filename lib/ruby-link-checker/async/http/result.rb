module LinkChecker
  module Async
    module HTTP
      # A thin, case-insensitive wrapper around Protocol::HTTP::Headers,
      # since Protocol::HTTP::Headers#[] expects a lower-cased key.
      class Headers
        def initialize(headers)
          @headers = headers
        end

        def [](key)
          @headers[key.to_s.downcase]
        end
      end

      # Wraps an Async::HTTP response to expose a `code` and case-insensitive
      # `headers`, similar to the other checkers' response objects.
      class Response
        attr_reader :status, :headers

        def initialize(response)
          @status = response.status
          @headers = Headers.new(response.headers)
        end

        def code
          @status.to_s
        end
      end

      class Result < ::LinkChecker::Result
        attr_accessor :request, :response

        def initialize(uri, method, original_uri, request, response, options)
          @request = request
          @response = response && Response.new(response)
          super(uri, method, original_uri, options)
        end

        def error?
          false
        end

        def failure?
          !success? && !redirect?
        end

        def code
          @code ||= begin
            response.status
          rescue StandardError
            -1
          end
        end

        def request_headers
          Headers.new(request.headers)
        end

        def redirect_to
          return nil unless response

          response.headers['location']
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
