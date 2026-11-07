module LinkChecker
  class Task
    include LinkChecker::Callbacks

    attr_reader :uri, :original_uri, :method, :logger, :options, :checker
    attr_accessor :delay

    def initialize(checker, uri, method, original_uri, options = {})
      @checker = checker
      @logger = checker.logger
      @uri = uri
      @original_uri = original_uri || @uri
      @method = method
      @options = options
      @delay = 0
    end

    def run!
      raise NotImplementedError
    end
  end
end
