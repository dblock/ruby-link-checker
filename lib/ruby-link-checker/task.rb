module LinkChecker
  class Task
    include LinkChecker::Callbacks

    attr_reader :uri, :original_uri, :method, :logger, :options, :checker

    def initialize(checker, uri, method, original_uri, options = {})
      @checker = checker
      @logger = checker.logger
      @uri = uri
      @original_uri = original_uri || @uri
      @method = method
      @options = options
    end

    def run!
      raise NotImplementedError
    end
  end
end
