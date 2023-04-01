module LinkChecker
  class Task
    include LinkChecker::Callbacks

    attr_reader :uri, :method, :logger, :options, :checker

    def initialize(checker, uri, method, options = {})
      @checker = checker
      @logger = checker.logger
      @uri = uri
      @method = method
      @options = options
    end

    def run!
      raise NotImplementedError
    end
  end
end
