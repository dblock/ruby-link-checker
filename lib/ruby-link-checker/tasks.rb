module LinkChecker
  class Tasks
    include LinkChecker::Callbacks

    attr_reader :result, :uri, :original_uri

    def initialize(checker, task_klass, uri, methods, options = {})
      @uri = uri
      @retries_left = checker.retries
      @methods_left = methods.dup
      @methods = methods.dup
      @task_klass = task_klass
      @checker = checker
      @logger = checker.logger
      @redirects = [uri]
      @options = options
      raise ArgumentError, :tasks_klass unless @task_klass && @task_klass < ::LinkChecker::Task
    end

    def new_task(uri, method, original_uri, options)
      task_klass.new(checker, uri, method, original_uri, options)
    end

    def execute!
      if retry?
        @retries_left -= 1
        retry! @result
        _queue_task(uri, method, original_uri || uri, options)
      elsif methods_left.any?
        @method = methods_left.shift
        @uri = URI(@uri) unless @uri.is_a?(URI)
        _queue_task(uri, method, original_uri || uri, options)
      elsif @result && result.error?
        error! @result
      else
        failure! @result
      end
    rescue StandardError => e
      logger.error("#{self}##{__method__}") { e }
      _handle_result ResultError.new(uri, method, original_uri || uri, e, options)
    end

    private

    attr_reader :logger, :methods_left, :options, :task_klass, :redirects, :checker, :method

    def retries
      checker.retries
    end

    def first_time?
      !!method.nil?
    end

    def retries_left
      @retries_left ||= retries
    end

    def retry?
      !first_time? && retries_left > 0
    end

    def _queue_task(uri, method, original_uri, options = {})
      task = new_task(uri, method, original_uri, options)
      task.on :result do |result|
        _handle_result result
      end
      task.run!
    rescue StandardError => e
      logger.error("#{self}##{__method__}") { e }
      _handle_result ResultError.new(uri, method, original_uri, e, options)
    end

    def _retries_left_s
      return nil unless retry? && retries_left > 0

      if retries_left == 1
        '1 retry left'
      else
        "#{retries_left} retries left"
      end
    end

    def _handle_result(result)
      @result = result
      retry_text = " (#{_retries_left_s})" if retry? && (result.error? || result.failure?)
      logger.info "#{' ' * (redirects.count - 1)}#{result}#{retry_text}"
      result! result
      if result.redirect?
        redirect! result
        redirected_to_uri = URI.join(uri, result.redirect_to)
        if redirects.include?(redirected_to_uri)
          raise LinkChecker::Errors::RedirectLoopError,
                redirects.push(redirected_to_uri)
        end

        redirects << redirected_to_uri
        _queue_task(redirected_to_uri, result.method, uri, options)
      elsif result.success?
        success! result
      else
        @redirects = [uri]
        execute!
      end
    rescue StandardError => e
      logger.error("#{self}##{__method__}") { e } rescue nil
      error_result = ResultError.new(result.uri, result.method, result.result_uri, e, options)
      result! error_result
      error! error_result
    end
  end
end
