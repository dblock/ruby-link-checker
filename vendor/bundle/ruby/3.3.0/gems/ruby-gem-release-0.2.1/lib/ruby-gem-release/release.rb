# frozen_string_literal: true

require 'date'

module RubyGemRelease
  class Release
    attr_reader :version, :previous_version, :next_version, :date

    def initialize(date:, version:, previous_version:, next_version: nil, dry_run: false)
      raise ArgumentError, 'dry_run must be true or false' unless [true, false].include?(dry_run)

      validate_versions(version, previous_version, next_version)
      raise ArgumentError, 'date must be a Date' unless date.instance_of?(Date)

      @version = version.dup.freeze
      @previous_version = previous_version.dup.freeze
      @next_version = next_version&.dup&.freeze
      @date = date.dup.freeze
      @dry_run = dry_run
      freeze
    end

    def with_version(version)
      self.class.new(version: version, previous_version: @previous_version, date: @date, next_version: @next_version, dry_run: @dry_run)
    end

    def with_next_version(version)
      self.class.new(version: @version, previous_version: @previous_version, date: @date, next_version: version, dry_run: @dry_run)
    end

    def dry_run?
      @dry_run
    end

    private

    def validate_versions(version, previous_version, next_version)
      raise ArgumentError, 'release versions must be strings' unless [version, previous_version].all?(String) && (next_version.nil? || next_version.is_a?(String))
    end
  end
end
