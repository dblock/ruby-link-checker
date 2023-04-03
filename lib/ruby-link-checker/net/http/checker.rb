module LinkChecker
  module Net
    module HTTP
      class Task < ::LinkChecker::Task
        def run!
          ::Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
            http.read_timeout = checker.read_timeout if checker.read_timeout
            http.open_timeout = checker.open_timeout if checker.open_timeout
            request = ::Net::HTTPGenericRequest.new(method, false, true, uri)
            request['User-Agent'] = checker.user_agent
            response = http.request(request)
            result! Result.new(uri, method, original_uri, request, response, options)
          end
        end
      end

      class Checker < LinkChecker::Checker
        extend ::LinkChecker::Net::HTTP::Config
        attr_accessor(*LinkChecker::Net::HTTP::Config::ATTRIBUTES)

        def initialize(options = {})
          LinkChecker::Net::HTTP::Config::ATTRIBUTES.each do |key|
            send("#{key}=", options[key] || LinkChecker::Net::HTTP::Config.send(key))
          end
          super options
        end
      end
    end
  end
end
