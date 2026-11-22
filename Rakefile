# frozen_string_literal: true

require 'rubygems'
require 'bundler/gem_tasks'

# Releases run through the GitHub Actions workflow, see RELEASING.md.
%w[release release:rubygem_push release:source_control_push].each do |name|
  Rake::Task[name].clear
  desc 'Disabled; releases run through GitHub Actions, see RELEASING.md'
  task(name) { abort "#{name} is disabled; releases run through GitHub Actions" }
end

Bundler.setup :default, :development

require 'rspec/core'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop)

require 'ruby-gem-release/workflow/ruby_gem'
require 'ruby-gem-release/changelog'

RubyGemRelease::Workflow::RubyGem.new(
  version: RubyGemRelease::Version::RubyConstant.new(path: 'lib/ruby-link-checker/version.rb', constant: 'VERSION'),
  changelog: RubyGemRelease::Changelog::Intridea.new(placeholder: '* Your contribution here.')
).install_tasks

task default: %i[rubocop spec]
