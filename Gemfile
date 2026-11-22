# frozen_string_literal: true

source 'http://rubygems.org'

gemspec

gem 'rake'

group :development, :test do
  gem 'commonmarker', '~> 2.10', require: false
  gem 'danger', '>= 9.6.2'
  gem 'danger-changelog', '0.8.0'
  gem 'danger-pr-comment'
  gem 'danger-toc', '0.2.0'
  gem 'rspec', '~> 3.0'
  gem 'rubocop', '~> 1.0'
  gem 'rubocop-rake'
  gem 'rubocop-rspec'
  gem 'ruby-gem-release', '~> 0.9.0', require: false
  gem 'vcr'
  gem 'webmock'
end

group :test do
  gem 'simplecov', require: false
end
