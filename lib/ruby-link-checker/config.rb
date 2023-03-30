# frozen_string_literal: true

module LinkChecker
  module Config
    extend self

    ATTRIBUTES = %i[
      methods
      user_agent
      logger
    ].freeze

    attr_accessor(*Config::ATTRIBUTES)

    def reset
      self.methods = %w[HEAD GET]
      self.user_agent = "Ruby Link Checker/#{LinkChecker::VERSION}"
      self.logger = nil
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
