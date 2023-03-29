# frozen_string_literal: true

module LinkChecker
  class Checker
    attr_reader :callbacks
    attr_accessor(*Config::ATTRIBUTES)

    def initialize(options = {})
      @callbacks = Hash.new { |h, k| h[k] = [] }
      LinkChecker::Config::ATTRIBUTES.each do |key|
        send("#{key}=", options[key] || LinkChecker.config.send(key))
      end
      raise ArgumentError, "Missing methods." if methods&.none?
      @logger ||= LinkChecker::Config.logger || LinkChecker::Logger.default
    end

    def on(event, &block)
      callbacks[event.to_s] << block
    end

    def failure!(*args)
      callback(:failure, *args)
    end

    def success!(*args)
      callback(:success, *args)
    end

    def error!(*args)
      callback(:error, *args)
    end

    def check!(uri, options = {})
      result = nil
      uri = URI(uri) unless uri.is_a?(URI)
      _checking! uri, options do |ctx|
        methods.each do |method|
          result = _check!(uri, method, ctx, options)
          logger.info "#{uri}: #{result}"
          if result.success?
            success! uri, result
            return result
          end
        end
      end
      failure! uri, result
      result
    rescue StandardError => e
      logger.warn "#{uri}: #{e}"
      error! uri, e
      ResultError.new uri, e
    end

    private

    def _checking!(_uri, options = {})
      yield self, options
    end

    def _check!(_uri, _method, _ctx, _options = {})
      raise NotImplementedError
    end

    def callback(event, *data)
      callbacks = self.callbacks[event.to_s]
      return false unless callbacks

      callbacks.each do |c|
        c.call(*data)
      end
      true
    rescue StandardError => e
      logger.error("#{self}##{__method__}") { e }
      false
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
