module LinkChecker
  module Net
    class HTTP
      class Checker < LinkChecker::Checker
        def _checking!(uri, options = {})
          ::Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
            yield http, options
          end
        end

        def _check!(uri, method, ctx, _options = {})
          request = http_request(uri, method)
          response = ctx.request(request)
          logger.info "#{method} #{uri}: #{response.code}"
          Result.new uri, request, response
        end

        private

        def http_request(uri, method)
          case method
          when 'GET'
            ::Net::HTTP::Get.new(uri)
          when 'HEAD'
            ::Net::HTTP::Head.new(uri)
          else
            raise ArgumentError, "Unsupported method #{method}."
          end
        end
      end
    end
  end
end
