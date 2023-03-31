module LinkChecker
  module Net
    class HTTP
      class Task < ::LinkChecker::Task
        def run!
          ::Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
            request = http_request(uri, method)
            response = http.request(request)
            logger.debug "#{method} #{uri}: #{response.code}"
            result! Result.new(uri, method, request, response)
          end
        end

        private

        def http_request(uri, method)
          case method
          when 'GET'
            ::Net::HTTP::Get.new(uri)
          when 'HEAD'
            ::Net::HTTP::Head.new(uri)
          else
            raise LinkChecker::Errors::InvalidHttpMethodError, method
          end
        end
      end

      class Checker < LinkChecker::Checker; end
    end
  end
end
