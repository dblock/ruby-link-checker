# frozen_string_literal: true

module LinkChecker
  module Config
    extend self

    ATTRIBUTES = %i[
      methods
      user_agent
      headers
      host_headers
      logger
      retries
      max_redirects
      retry_status_codes
      blocked_status_codes
      detect_challenges
      retry_after
      retry_backoff
      retry_jitter
      max_retry_delay
      respect_retry_after
      deduplicate
      cache
      max_concurrency_per_host
      min_host_interval
      rate_limit_retries
      rate_limit_status_codes
      rate_limit_backoff
      max_rate_limit_delay
    ].freeze

    attr_accessor(*Config::ATTRIBUTES)

    DEFAULT_USER_AGENT = "Ruby Link Checker/#{LinkChecker::VERSION}".freeze

    def reset
      self.methods = %w[HEAD GET]
      self.user_agent = DEFAULT_USER_AGENT
      self.headers = {}
      self.host_headers = {}
      self.logger = nil
      self.retries = 0
      self.max_redirects = 20
      self.retry_status_codes = [408, 425, 429, 500, 502, 503, 504]
      self.blocked_status_codes = [401, 403, 429, 999]
      self.detect_challenges = true
      self.retry_after = 0
      self.retry_backoff = 1
      self.retry_jitter = 0
      self.max_retry_delay = 60
      self.respect_retry_after = false
      self.deduplicate = false
      self.cache = nil
      self.max_concurrency_per_host = nil
      self.min_host_interval = 0
      self.rate_limit_retries = 2
      self.rate_limit_status_codes = [429]
      self.rate_limit_backoff = 1
      self.max_rate_limit_delay = 30
    end

    def host_headers=(value)
      value ||= {}
      valid = value.is_a?(Hash) && value.all? do |host, host_values|
        (host.is_a?(String) || host.is_a?(Regexp)) && host_values.is_a?(Hash)
      end
      raise ArgumentError, "Invalid host headers: #{value}" unless valid

      @host_headers = value.transform_keys { |host| host.is_a?(String) ? host.downcase : host }
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

    def blocked_status_codes=(value)
      unless value.nil? || (value.is_a?(Array) && value.all? { |code| code.is_a?(Integer) && code.between?(100, 999) })
        raise ArgumentError, "Invalid blocked status codes: #{value}"
      end

      @blocked_status_codes = value&.dup || []
    end

    def detect_challenges=(value)
      raise ArgumentError, "Invalid detect_challenges: #{value}" unless [true, false].include?(value)

      @detect_challenges = value
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

    def max_concurrency_per_host=(value)
      unless value.nil? || (value.is_a?(Integer) && value.positive?)
        raise ArgumentError, "Invalid concurrency limit per host: #{value}"
      end

      @max_concurrency_per_host = value
    end

    def min_host_interval=(value)
      validate_number!(:min_host_interval, value, 0)
      @min_host_interval = value
    end

    def rate_limit_retries=(value)
      raise ArgumentError, "Invalid number of rate limit retries: #{value}" unless value.is_a?(Integer) && value >= 0

      @rate_limit_retries = value
    end

    def rate_limit_status_codes=(value)
      unless value.nil? || (value.is_a?(Array) && value.all? { |code| code.is_a?(Integer) && code.between?(100, 999) })
        raise ArgumentError, "Invalid rate limit status codes: #{value}"
      end

      @rate_limit_status_codes = value&.dup || []
    end

    def rate_limit_backoff=(value)
      validate_number!(:rate_limit_backoff, value, 0)
      @rate_limit_backoff = value
    end

    def max_rate_limit_delay=(value)
      validate_number!(:max_rate_limit_delay, value, 0)
      @max_rate_limit_delay = value
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
