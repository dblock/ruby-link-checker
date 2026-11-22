# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'tempfile'
require 'uri'

module LinkChecker
  class CachedResult < Result
    attr_reader :code, :challenge

    def initialize(data, uri)
      @code = data.fetch('code')
      super(URI(data.fetch('result_uri')), data.fetch('method'), URI(uri.to_s))
      @redirects = data.fetch('redirects').map do |hop_uri, code, to|
        Redirect.new(uri: URI(hop_uri), code: code, to: URI(to))
      end.freeze
      @blocked = data['blocked'] == true
      @challenge = data['challenge'] if data['challenge'].is_a?(String)
      @cached = true
    end

    def success?
      !blocked?
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

      @prune = options.fetch(:prune, false)
      raise ArgumentError, 'Cache prune must be true or false' unless [true, false].include?(@prune)

      @file = File.expand_path(options[:file])
      @logger = logger
      @seen = Set.new
    end

    # Whether to prune entries that were not used when a run finishes.
    def prune?
      @prune
    end

    def fetch(key, uri)
      @seen << key
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
      @seen << key
      return unless result.success? || (result.blocked? && @blocked_ttl)
      return if URI(result.result_uri.to_s).userinfo
      return if result.redirects.any? { |hop| URI(hop.uri.to_s).userinfo || URI(hop.to.to_s).userinfo }

      update_entries do |entries|
        entries[key] = {
          'checked_at' => Time.now.to_f,
          'method' => result.method,
          'code' => result.code,
          'result_uri' => result.result_uri.to_s,
          'redirects' => result.redirects.map { |hop| [hop.uri.to_s, hop.code, hop.to.to_s] }
        }
        entries[key].merge!('blocked' => true, 'challenge' => result.challenge) if result.blocked?
        entries
      end
    rescue IOError, SystemCallError, JSON::GeneratorError
      @logger.warn("Unable to write link cache #{@file}; result was not cached")
    end

    # Removes entries that this cache instance neither read nor wrote, and expired entries.
    # Returns the number of entries removed.
    def prune!
      return 0 unless File.exist?(@file)

      removed = 0
      update_entries do |entries|
        kept = entries.slice(*@seen)
        removed = read_entries.size - kept.size
        kept
      end
      @logger.info("Pruned #{removed} unused #{removed == 1 ? 'entry' : 'entries'} from link cache #{@file}")
      removed
    rescue IOError, SystemCallError, JSON::GeneratorError
      @logger.warn("Unable to prune link cache #{@file}")
      0
    end

    private

    # Atomically replaces the fresh entries with those returned by the block, under an exclusive lock.
    def update_entries
      directory = File.dirname(@file)
      FileUtils.mkdir_p(directory)
      File.open("#{@file}.lock", File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        entries = yield(read_entries.select { |_entry_key, data| fresh?(data) })
        Tempfile.create(['link-checker-', '.json'], directory) do |file|
          file.write(JSON.generate('version' => VERSION, 'entries' => entries))
          file.flush
          File.rename(file.path, @file)
        end
      end
    end

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
