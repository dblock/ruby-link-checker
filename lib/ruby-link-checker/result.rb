module LinkChecker
  class Result
    attr_accessor :uri, :result_uri, :method, :options, :checker

    def initialize(current_uri, method, original_uri, options = {})
      @uri = original_uri
      @result_uri = current_uri
      @method = method
      @options = options
    end

    def success?
      false
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
      "#{method} #{uri}#{result_uri == uri ? nil : ' (' + result_uri.to_s + ')'}: #{status_s} (#{code})"
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
  end
end
