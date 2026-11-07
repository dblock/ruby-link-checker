require 'timeout'
require 'socket'

module LinkChecker
  class Result
    attr_accessor :uri, :result_uri, :method, :options, :checker
    attr_writer :cached

    def initialize(current_uri, method, original_uri, options = {})
      @uri = original_uri
      @result_uri = current_uri
      @method = method
      @options = options
    end

    def success?
      false
    end

    def cached?
      !!@cached
    end

    def failure?
      false
    end

    def error?
      false
    end

    def redirect?
      false
    end

    def redirect_to
      nil
    end

    def request_headers
      {}
    end

    def response_headers
      {}
    end

    def error_type
      nil
    end

    def code
      nil
    end

    def error
      nil
    end

    def to_s
      status_s = if success?
                   'OK'
                 elsif failure?
                   'FAIL'
                 elsif redirect?
                   'REDIRECT'
                 else
                   'ERROR'
                 end
      "#{method} #{uri}#{result_uri == uri ? nil : ' (' + result_uri.to_s + ')'} : #{status_s} (#{code})"
    end
  end

  class ResultError < Result
    attr_accessor :error

    def initialize(uri, method, original_uri, error, options = {})
      @error = error
      super uri, method, original_uri, options
    end

    def error?
      true
    end

    def code
      error.class.name
    end

    def error_type
      return :timeout if error.is_a?(Timeout::Error)
      return :timeout if defined?(::Async::TimeoutError) && error.is_a?(::Async::TimeoutError)
      return error.error_type if error.is_a?(LinkChecker::Errors::ConnectionError)
      return :connection if [IOError, SystemCallError, SocketError].any? { |klass| error.is_a?(klass) }

      :other
    end
  end
end
