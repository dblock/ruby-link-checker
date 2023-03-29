# frozen_string_literal: true
require 'logger'

module LinkChecker
  class Logger < ::Logger
    def self.default
      return @default if @default

      logger = new STDOUT
      logger.level = Logger::WARN
      @default = logger
    end
  end
end