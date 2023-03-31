# frozen_string_literal: true

module LinkChecker
  module Callbacks
    def callbacks
      @callbacks ||= Hash.new { |h, k| h[k] = [] }
    end

    def delegates
      @delegates ||= []
    end

    def on(event = nil, &block)
      if event
        callbacks[event.to_s] << block
      else
        delegates << block
      end
    end

    def method_missing(m, *args, &block)
      if m.to_s[-1] == '!'
        callback(m.to_s[...-1].to_sym, *args)
      else
        super
      end
    end

    private

    def callback(event, *data)
      delegates.each do |c|
        c.call(event, *data)
      end

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
  end
end
