# frozen_string_literal: true

require_relative '../package/ruby_gem'
require_relative '../source_control/git'
require_relative '../release'
require_relative '../version/ruby_constant'

module RubyGemRelease
  module Workflow
    class Context
      def configure!
        raise ArgumentError, 'dry-run must be true or false' unless %w[true false].include?(ENV.fetch('DRY_RUN'))

        names = %w[INPUT_VERSION INPUT_GEMSPEC DEFAULT_BRANCH DRY_RUN GIT_USER_NAME GIT_USER_EMAIL RUBYGEMS_OWNER]
        export(names.to_h { |name| [name, ENV.fetch(name)] })
      end

      def capture!
        dry_run = ENV.fetch('DRY_RUN', 'false') == 'true'
        check_branch(dry_run)
        package = Package::RubyGem.new(gemspec: ENV.fetch('INPUT_GEMSPEC', nil))
        release = initial_release(package, dry_run: dry_run)
        git = configured_git
        git.check_current!(release)
        export('GEMSPEC' => package.gemspec, 'RELEASE_PREVIOUS_VERSION' => release.version,
               'RELEASE_DATE' => release.date.iso8601, 'RELEASE_INITIAL_COMMIT' => git.head)
      end

      def resolve!
        version = Package::RubyGem.new.version
        validate_version(version)
        expected = ENV.fetch('INPUT_VERSION', '')
        raise "Prepared version #{version} does not match expected version #{expected}" unless expected.empty? || version == expected

        SourceControl::Git.new.check_tag!(version)
        export('RELEASE_VERSION' => version)
      end

      private

      def initial_release(package, dry_run:)
        version = package.version
        validate_version(version)
        validate_version(ENV.fetch('INPUT_VERSION')) unless ENV.fetch('INPUT_VERSION', '').empty?
        Release.new(version: version, previous_version: version, date: Time.now.utc.to_date, dry_run: dry_run)
      end

      def configured_git
        SourceControl::Git.new.tap do |git|
          git.configure!(name: ENV.fetch('GIT_USER_NAME', 'github-actions[bot]'),
                         email: ENV.fetch('GIT_USER_EMAIL', 'github-actions[bot]@users.noreply.github.com'))
        end
      end

      def check_branch(dry_run)
        return if dry_run
        return if ENV.fetch('GITHUB_REF') == "refs/heads/#{ENV.fetch('DEFAULT_BRANCH')}"

        raise 'Releases must run from the default branch'
      end

      def validate_version(version)
        raise ArgumentError, 'Version must be MAJOR.MINOR.PATCH without leading zeros' unless Version::RubyConstant::PATTERN.match?(version)
      end

      def export(values)
        raise ArgumentError, 'Workflow values cannot contain line breaks' if values.values.any? { |value| value.match?(/[\r\n]/) }

        File.open(ENV.fetch('GITHUB_ENV'), 'a') do |file|
          values.each do |key, value|
            file.puts "#{key}=#{value}"
          end
        end
      end
    end
  end
end
