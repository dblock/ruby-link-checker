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
      @cached = true
    end

    def success?
      true
    end
  end

  class Cache
    VERSION = 1

    def initialize(options, logger:)
      unless options.is_a?(Hash) && options[:file].is_a?(String) && !options[:file].strip.empty?
        raise ArgumentError, 'Cache requires a file path'
      end

      @ttl = options[:ttl]
      unless @ttl.is_a?(Numeric) && @ttl.real? && @ttl.finite? && @ttl.positive?
        raise ArgumentError, 'Cache requires a positive, finite TTL in seconds'
      end

      @file = File.expand_path(options[:file])
      @logger = logger
    end

    def fetch(key, uri)
      data = read_entries[key]
      return unless fresh?(data) && data['code'].is_a?(Integer) && data['code'].between?(200, 299)
      return unless data['method'].is_a?(String) && data['result_uri'].is_a?(String)

      parsed = URI(data['result_uri'])
      return unless %w[http https].include?(parsed.scheme) && parsed.host && !parsed.userinfo

      CachedResult.new(data, uri)
    rescue URI::InvalidURIError
      nil
    end

    def store(key, result)
      return unless result.success?
      return if URI(result.result_uri.to_s).userinfo

      directory = File.dirname(@file)
      FileUtils.mkdir_p(directory)
      File.open("#{@file}.lock", File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        entries = read_entries.select { |_entry_key, data| fresh?(data) }
        entries[key] = {
          'checked_at' => Time.now.to_f,
          'method' => result.method,
          'code' => result.code,
          'result_uri' => result.result_uri.to_s
        }
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

    def fresh?(data)
      return false unless data.is_a?(Hash)

      timestamp = data['checked_at']
      now = Time.now.to_f
      timestamp.is_a?(Numeric) && timestamp.finite? && timestamp <= now && now - timestamp < @ttl
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
