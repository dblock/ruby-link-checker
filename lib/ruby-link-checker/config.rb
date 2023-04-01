# frozen_string_literal: true

module LinkChecker
  module Config
    extend self

    ATTRIBUTES = %i[
      methods
      user_agent
      logger
      retries
    ].freeze

    attr_accessor(*Config::ATTRIBUTES)

    def reset
      self.methods = %w[HEAD GET]
      self.user_agent = "Ruby Link Checker/#{LinkChecker::VERSION}"
      self.logger = nil
      self.retries = 0
    end

    def retries=(value)
      raise ArgumentError, "Invalid number of retries: #{value}" unless value.is_a?(Integer) && value >= 0

      @retries = value
    end
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

LinkChecker::Config.reset
