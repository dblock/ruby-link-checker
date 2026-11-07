# frozen_string_literal: true

source 'http://rubygems.org'

gemspec

gem 'rake'

group :development, :test do
  gem 'danger'
  gem 'danger-changelog', '0.8.0'
  gem 'danger-pr-comment'
  gem 'danger-toc', '0.2.0'
  # Temporary until Danger's git 6 support lands: https://github.com/danger/danger/pull/1561
  gem 'git', '< 6', require: false
  gem 'rspec', '~> 3.0'
  gem 'rubocop', '~> 1.0'
  gem 'rubocop-rake'
  gem 'rubocop-rspec'
  gem 'ruby-gem-release', '~> 0.2.0', require: false
  gem 'vcr'
  gem 'webmock'
end

group :test do
  gem 'simplecov', require: false
end
