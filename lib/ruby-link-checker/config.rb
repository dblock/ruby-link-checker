# frozen_string_literal: true

module LinkChecker
  module Config
    extend self

    ATTRIBUTES = %i[
      methods
      user_agent
      headers
      logger
      retries
      max_redirects
      retry_status_codes
      retry_after
      retry_backoff
      retry_jitter
      max_retry_delay
      respect_retry_after
      deduplicate
      cache
    ].freeze

    attr_accessor(*Config::ATTRIBUTES)

    def reset
      self.methods = %w[HEAD GET]
      self.user_agent = "Ruby Link Checker/#{LinkChecker::VERSION}"
      self.headers = {}
      self.logger = nil
      self.retries = 0
      self.max_redirects = 20
      self.retry_status_codes = [408, 425, 429, 500, 502, 503, 504]
      self.retry_after = 0
      self.retry_backoff = 1
      self.retry_jitter = 0
      self.max_retry_delay = 60
      self.respect_retry_after = false
      self.deduplicate = false
      self.cache = nil
    end

    def retries=(value)
      raise ArgumentError, "Invalid number of retries: #{value}" unless value.is_a?(Integer) && value >= 0

      @retries = value
    end

    def max_redirects=(value)
      raise ArgumentError, "Invalid redirect limit: #{value}" unless value.is_a?(Integer) && value >= 0

      @max_redirects = value
    end

    def retry_status_codes=(value)
      unless value.nil? || (value.is_a?(Array) && value.all? { |code| code.is_a?(Integer) && code.between?(100, 599) })
        raise ArgumentError, "Invalid retry status codes: #{value}"
      end

      @retry_status_codes = value&.dup
    end

    def retry_after=(value)
      validate_number!(:retry_after, value, 0)
      @retry_after = value
    end

    def retry_backoff=(value)
      validate_number!(:retry_backoff, value, 1)
      @retry_backoff = value
    end

    def retry_jitter=(value)
      validate_number!(:retry_jitter, value, 0)
      raise ArgumentError, "Invalid retry_jitter: #{value}" if value > 1

      @retry_jitter = value
    end

    def max_retry_delay=(value)
      validate_number!(:max_retry_delay, value, 0)
      @max_retry_delay = value
    end

    private

    def validate_number!(name, value, minimum)
      return if value.is_a?(Numeric) && value.real? && value.finite? && value >= minimum

      raise ArgumentError, "Invalid #{name}: #{value}"
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
