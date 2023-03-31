module LinkChecker
  class Task
    include LinkChecker::Callbacks

    attr_reader :uri
    attr_reader :method, :logger

    def initialize(uri, method, options = {})
      @uri = uri
      @method = method
      @logger = options[:logger]
    end

    def run!
      raise NotImplementedError
    end
  end

  class Tasks
    include LinkChecker::Callbacks

    attr_reader :result
    attr_reader :uri

    def initialize(uri, methods, options = {})
      @uri = uri
      @methods = methods
      @options = options
      @task_klass = options[:task_klass]
      @logger = options[:logger]
      @redirects = [uri]
      raise ArgumentError, :tasks_klass unless @task_klass && @task_klass < ::LinkChecker::Task
    end

    def new_task(uri, method, options)
      task_klass.new(uri, method, options)
    end

    def execute!
      if methods.any?
        method = methods.shift
        @uri = URI(@uri) unless @uri.is_a?(URI)
        _queue_task(uri, method, options)
      elsif @result && result.error?
        error! @result
      elsif @result && result.failure?
        failure! @result
      else
        failure! @result
      end
    rescue StandardError => e
      _handle_result ResultError.new(uri, method, e)
    end

    private

    attr_reader :logger, :methods, :options, :task_klass, :redirects

    def _queue_task(uri, method, options = {})
      task = new_task(uri, method, options)
      task.on :result do |result|
        _handle_result result
      end
      task.run!
    rescue StandardError => e
      _handle_result ResultError.new(uri, method, e)
    end

    def _handle_result(result)
      @result = result
      logger.info "#{' ' * (redirects.count - 1)}#{result}"
      result! result
      if result.redirect?
        redirect! result
        redirected_to_uri = URI.join(uri, result.redirect_to)
        if redirects.include?(redirected_to_uri)
          raise LinkChecker::Errors::RedirectLoopError,
                redirects.push(redirected_to_uri)
        end

        redirects << redirected_to_uri
        _queue_task(redirected_to_uri, result.method, options)
      elsif result.success?
        success! result
      else
        execute!
      end
    rescue StandardError => e
      _handle_result ResultError.new(result.uri, result.method, e)
    end
  end
end
