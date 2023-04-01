# frozen_string_literal: true

module LinkChecker
  module Net
    module HTTP
      module Config
        extend self

        ATTRIBUTES = %i[
          read_timeout
          open_timeout
        ].freeze

        attr_accessor(*Config::ATTRIBUTES)

        def reset
          self.read_timeout = nil
          self.open_timeout = nil
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

LinkChecker::Net::HTTP::Config.reset
