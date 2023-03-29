module LinkChecker
  class Result
    attr_accessor :uri

    def initialize(uri)
      @uri = uri
    end

    def success?
      raise NotImplementedError
    end

    def failure?
      raise NotImplementedError
    end

    def error?
      raise NotImplementedError
    end

    def to_s
      status_s = if success?
                   'OK'
                 elsif failure?
                   'FAIL'
                 else
                   'ERROR'
                 end
      "#{uri}: #{status_s}"
    end
  end

  class ResultSuccess < Result
    def success?
      true
    end

    def failure?
      false
    end

    def error?
      false
    end
  end

  class ResultFailure < Result
    def success?
      false
    end

    def failure?
      true
    end

    def error?
      false
    end
  end

  class ResultError < Result
    attr_accessor :error

    def initialize(uri, error)
      @error = error
      super uri
    end

    def success?
      false
    end

    def failure?
      false
    end

    def error?
      true
    end
  end
end
