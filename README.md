Ruby LinkChecker
================

[![Gem Version](http://img.shields.io/gem/v/ruby-link-checker.svg)](http://badge.fury.io/rb/ruby-link-checker)
[![Build Status](https://github.com/dblock/ruby-link-checker/workflows/test/badge.svg?branch=main)](https://github.com/dblock/ruby-link-checker/actions)
[![Code Climate](https://codeclimate.com/github/dblock/ruby-link-checker.svg)](https://codeclimate.com/github/dblock/ruby-link-checker)
[![Test Coverage](https://api.codeclimate.com/v1/badges/164f1e23fc706b6efa63/test_coverage)](https://codeclimate.com/github/dblock/ruby-link-checker/test_coverage)

A fast Ruby link checker with support for multiple HTTP libraries.

## Table of Contents

- [Usage](#usage)
- [Dependencies](#dependencies)
- [Basic Usage](#basic-usage)
- [Checkers](#checkers)
    - [LinkChecker::Typhoeus::Hydra](#linkcheckertyphoeushydra)
    - [LinkChecker::Net::HTTP](#linkcheckernethttp)
- [Contributing](#contributing)
- [Copyright and License](#copyright-and-license)

## Usage

### Dependencies

The `LinkChecker::Typhoeus::Hydra` link checker is recommended. 

Add `typhoeus` and `ruby-link-checker` to your `Gemfile` and run `bundle install.

### Basic Usage

```ruby
require 'typhoeus'
require 'ruby-link-checker'

# create a checker
checker = LinkChecker::Typhoeus::Hydra::Checker.new # create a new checker

# queue URLs to check
links = [...]
links.each do |url|
  checker.check url
end

# run the checks
checker.run

# display buckets of results
checker.results.each_pair do |bucket, results|
   puts "#{bucket}: #{results.size}"
end
```

### Checkers

#### LinkChecker::Typhoeus::Hydra

Fast link checker that uses [Typhoeus](https://typhoeus.github.io/). Anecdotal benchmarking on a M1 mac and T1 Internet yields ~50 URLs per second.

```ruby
require 'typhoeus'
require 'ruby-link-checker'

checker = LinkChecker::Typhoeus::Hydra::Checker.new(
  hydra: {
    max_concurrency: 25 # lower than the Typhoeus default of 200, seems to start breaking around 50+
  }
)

checker.logger.level = Logger::INFO # this will log requests and response codes, no output by default

links = [...] # array of URLs
links.each do |url|
  checker.check url
end

# examine failures as they come
checker.on :failure do |result|
  puts "FAIL: #{result.uri}: #{result.response.code}"
end    

checker.run # executes Hydra#run, will block until all requests have completed

# examine all results
checker.results.each_pair do |bucket, results|
  puts "#{bucket}: #{results.size}"
end
```

#### LinkChecker::Net::HTTP

Slow, sequential checker.

```ruby
require 'net/http'
require 'ruby-link-checker'

checker = LinkChecker::Net::HTTP::Checker.new
checker.logger.level = Logger::INFO

links = [...] # array of URLs
links.each do |url|
  checker.check url
end

# examine all results
checker.results.each_pair do |bucket, results|
  puts "#{bucket}: #{results.size}"
end
```

## Contributing

You're encouraged to contribute to ruby-link-checker. See [CONTRIBUTING](CONTRIBUTING.md) for details.

## Copyright and License

Copyright (c) Daniel Doubrovkine and [Contributors](CHANGELOG.md).

This project is licensed under the [MIT License](LICENSE.md).
