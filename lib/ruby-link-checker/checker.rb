# frozen_string_literal: true

module LinkChecker
  class Checker
    include LinkChecker::Callbacks

    attr_accessor(*Config::ATTRIBUTES)

    def initialize(options = {})
      LinkChecker::Config::ATTRIBUTES.each do |key|
        send("#{key}=", options[key] || LinkChecker.config.send(key))
      end
      raise ArgumentError, "Missing methods." if methods&.none?
      @logger ||= options[:logger] || LinkChecker::Config.logger || LinkChecker::Logger.default
    end

    def task_klass
      @task_klass ||= begin
        module_name = self.class.name.split("::")[...-1].join('::')
        Object.const_get("#{module_name}::Task")
      end
    end

    def check!(uri, options = {})
      tasks = Tasks.new(uri, methods, options.merge(logger: @logger, task_klass: task_klass))
      tasks.on do |event, *args|
        callback event, *args
      end
      tasks.execute!
    end

    class << self
      def configure
        block_given? ? yield(Config) : Config
      end

      def config
        Config
      end
    end
  end
end
