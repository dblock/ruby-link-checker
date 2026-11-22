# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'tempfile'
require 'uri'

module LinkChecker
  class CachedResult < Result
    attr_reader :code

    def initialize(data, uri)
      @code = data.fetch('code')
      super(URI(data.fetch('result_uri')), data.fetch('method'), URI(uri.to_s))
      @redirects = data.fetch('redirects').map do |hop_uri, code, to|
        Redirect.new(uri: URI(hop_uri), code: code, to: URI(to))
      end.freeze
      @blocked = data['blocked'] == true
      @challenge = data['challenge'] == true
      @cached = true
    end

    def success?
      !blocked?
    end

    def challenge?
      @challenge
    end
  end

  class Cache
    VERSION = 2

    def initialize(options, logger:)
      unless options.is_a?(Hash) && options[:file].is_a?(String) && !options[:file].strip.empty?
        raise ArgumentError, 'Cache requires a file path'
      end

      @ttl = options[:ttl]
      raise ArgumentError, 'Cache requires a positive, finite TTL in seconds' unless seconds?(@ttl)

      @blocked_ttl = options[:blocked_ttl]
      unless @blocked_ttl.nil? || seconds?(@blocked_ttl)
        raise ArgumentError, 'Cache requires a positive, finite blocked TTL in seconds'
      end

      @file = File.expand_path(options[:file])
      @logger = logger
    end

    def fetch(key, uri)
      data = read_entries[key]
      return unless fresh?(data) && data['code'].is_a?(Integer)
      return unless blocked?(data) ? data['code'].between?(100, 999) : data['code'].between?(200, 299)
      return unless data['method'].is_a?(String) && safe_uri?(data['result_uri'])
      return unless valid_redirects?(data['redirects'])

      CachedResult.new(data, uri)
    rescue URI::InvalidURIError
      nil
    end

    def store(key, result)
      return unless result.success? || (result.blocked? && @blocked_ttl)
      return if URI(result.result_uri.to_s).userinfo
      return if result.redirects.any? { |hop| URI(hop.uri.to_s).userinfo || URI(hop.to.to_s).userinfo }

      directory = File.dirname(@file)
      FileUtils.mkdir_p(directory)
      File.open("#{@file}.lock", File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        entries = read_entries.select { |_entry_key, data| fresh?(data) }
        entries[key] = {
          'checked_at' => Time.now.to_f,
          'method' => result.method,
          'code' => result.code,
          'result_uri' => result.result_uri.to_s,
          'redirects' => result.redirects.map { |hop| [hop.uri.to_s, hop.code, hop.to.to_s] }
        }
        entries[key].merge!('blocked' => true, 'challenge' => result.challenge?) if result.blocked?
        Tempfile.create(['link-checker-', '.json'], directory) do |file|
          file.write(JSON.generate('version' => VERSION, 'entries' => entries))
          file.flush
          File.rename(file.path, @file)
        end
      end
    rescue IOError, SystemCallError, JSON::GeneratorError
      @logger.warn("Unable to write link cache #{@file}; result was not cached")
    end

    private

    def seconds?(value)
      value.is_a?(Numeric) && value.real? && value.finite? && value.positive?
    end

    def safe_uri?(value)
      return false unless value.is_a?(String)

      parsed = URI(value)
      %w[http https].include?(parsed.scheme) && parsed.host && !parsed.userinfo
    end

    def valid_redirects?(redirects)
      redirects.is_a?(Array) && redirects.all? do |hop|
        hop.is_a?(Array) && hop.size == 3 && safe_uri?(hop[0]) && hop[1].is_a?(Integer) && safe_uri?(hop[2])
      end
    end

    def blocked?(data)
      data['blocked'] == true
    end

    # Successes expire after ttl and blocked results after blocked_ttl; blocked entries are stale without one.
    def fresh?(data)
      return false unless data.is_a?(Hash)

      ttl = blocked?(data) ? @blocked_ttl : @ttl
      timestamp = data['checked_at']
      now = Time.now.to_f
      !ttl.nil? && timestamp.is_a?(Numeric) && timestamp.finite? && timestamp <= now && now - timestamp < ttl
    end

    def read_entries
      data = JSON.parse(File.read(@file))
      return {} unless data.is_a?(Hash) && data['version'] == VERSION && data['entries'].is_a?(Hash)

      data['entries']
    rescue Errno::ENOENT
      {}
    rescue IOError, SystemCallError, JSON::ParserError
      @logger.warn("Unable to read link cache #{@file}; checking links normally")
      {}
    end
  end
end
