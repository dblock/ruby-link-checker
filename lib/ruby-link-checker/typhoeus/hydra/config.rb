# frozen_string_literal: true

module LinkChecker
  module Typhoeus
    module Hydra
      module Config
        extend self

        ATTRIBUTES = %i[
          timeout
          connecttimeout
        ].freeze

        attr_accessor(*Config::ATTRIBUTES)

        def reset
          self.timeout = 60
          self.connecttimeout = 10
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
  end
end

LinkChecker::Typhoeus::Hydra::Config.reset
