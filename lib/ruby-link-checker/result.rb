module LinkChecker
  class Result
    attr_accessor :uri, :method, :options, :checker

    def initialize(uri, method, options = {})
      @uri = uri
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
      "#{method} #{uri}: #{status_s} (#{code})"
    end
  end

  class ResultError < Result
    attr_accessor :error

    def initialize(uri, method, error)
      @error = error
      super uri, method
    end

    def error?
      true
    end

    def code
      error.class.name
    end
  end
end
