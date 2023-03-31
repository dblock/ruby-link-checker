module LinkChecker
  module Net
    class HTTP
      class Task < ::LinkChecker::Task
        def run!
          ::Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
            request = ::Net::HTTPGenericRequest.new(method, false, true, uri)
            response = http.request(request)
            logger.debug "#{method} #{uri}: #{response.code}"
            result! Result.new(uri, method, request, response)
          end
        end
      end

      class Checker < LinkChecker::Checker; end
    end
  end
end
