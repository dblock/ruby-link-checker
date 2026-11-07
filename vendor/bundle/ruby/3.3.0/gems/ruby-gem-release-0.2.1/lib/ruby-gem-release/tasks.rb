# frozen_string_literal: true

require 'rake'
require_relative 'release'
require_relative 'version/ruby_constant'
require_relative 'workflow/context'
require_relative 'workflow/ruby_gems_credentials'

module RubyGemRelease
  class Tasks
    include Rake::DSL

    def self.install
      instance = new
      yield instance if block_given?
      instance.install
    end

    def install
      namespace :release do
        install_callback_tasks
        install_publish_task
        install_workflow_tasks
      end
    end

    def before_release(&block)
      raise ArgumentError, 'before_release requires a block' unless block
      raise ArgumentError, 'before_release already configured' if @before_release

      @before_release = block
    end

    def after_release(&block)
      raise ArgumentError, 'after_release requires a block' unless block
      raise ArgumentError, 'after_release already configured' if @after_release

      @after_release = block
    end

    def publish(&block)
      raise ArgumentError, 'publish requires a block' unless block
      raise ArgumentError, 'publish already configured' if @publish

      @publish = block
    end

    private

    def install_workflow_tasks
      namespace :workflow do
        task(:configure) { Workflow::Context.new.configure! }
        task(:capture) { Workflow::Context.new.capture! }
        task(:resolve) { Workflow::Context.new.resolve! }
        task(:credentials) { Workflow::RubyGemsCredentials.new(owner: ENV.fetch('RUBYGEMS_OWNER')).configure! }
      end
    end

    def install_publish_task
      desc 'Run the release publication callback'
      task :publish do
        @publish&.call(context)
      end
    end

    def install_callback_tasks
      desc 'Run the before-release callback'
      task(:before_release) do
        release = context(before_release: true)
        @before_release&.call(release)
      end
      desc 'Run the next-version preparation callback'
      task(:after_release) do
        release = context
        @after_release&.call(release)
      end
    end

    def context(before_release: false)
      previous_version = ENV.fetch('RELEASE_PREVIOUS_VERSION')
      version = before_release ? previous_version : ENV.fetch('RELEASE_VERSION')
      date = ENV.fetch('RELEASE_DATE')
      validate_context_versions(version, previous_version)
      raise ArgumentError, 'release date is required in YYYY-MM-DD format' unless date.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      Release.new(version: version, previous_version: previous_version, date: Date.iso8601(date), dry_run: ENV.fetch('DRY_RUN', 'false') == 'true')
    end

    def validate_context_versions(*versions)
      pattern = Version::RubyConstant::PATTERN
      versions.compact.each do |value|
        raise ArgumentError, "invalid version: #{value.inspect}; expected MAJOR.MINOR.PATCH" unless value.is_a?(String) && pattern.match?(value)
      end
    end
  end
end
