Fast Ruby Link Checker
======================

[![Gem Version](http://img.shields.io/gem/v/ruby-link-checker.svg)](http://badge.fury.io/rb/ruby-link-checker)
[![Build Status](https://github.com/dblock/ruby-link-checker/workflows/test/badge.svg?branch=main)](https://github.com/dblock/ruby-link-checker/actions)
[![Code Climate](https://codeclimate.com/github/dblock/ruby-link-checker.svg)](https://codeclimate.com/github/dblock/ruby-link-checker)
[![Test Coverage](https://api.codeclimate.com/v1/badges/164f1e23fc706b6efa63/test_coverage)](https://codeclimate.com/github/dblock/ruby-link-checker/test_coverage)

A fast Ruby link checker with support for multiple HTTP libraries. Does not parse documents, just checks links. Fast. Anecdotal benchmarking on a M1 mac and T1 Internet yields ~50 URLs per second with `LinkChecker::Typhoeus::Hydra`.

## Table of Contents

- [Usage](#usage)
- [Dependencies](#dependencies)
- [Basic Usage](#basic-usage)
- [Checkers](#checkers)
  - [LinkChecker::Typhoeus::Hydra](#linkcheckertyphoeushydra)
  - [LinkChecker::Net::HTTP](#linkcheckernethttp)
- [Options](#options)
  - [Methods](#methods)
  - [Logger](#logger)
  - [User-Agent](#user-agent)
- [Global Configuration](#global-configuration)
- [Events](#events)
- [Contributing](#contributing)
- [Copyright and License](#copyright-and-license)

## Usage

### Dependencies

The [`LinkChecker::Typhoeus::Hydra`](lib/ruby-link-checker/typhoeus/hydra/checker.rb) link checker is recommended. 

Add `typhoeus` and `ruby-link-checker` to your `Gemfile` and run `bundle install`.

```ruby
gem 'typhoeus'
gem 'ruby-link-checker'
```

### Basic Usage

```ruby
require 'typhoeus'
require 'ruby-link-checker'

# create a new checker instance
checker = LinkChecker::Typhoeus::Hydra::Checker.new

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

#### [LinkChecker::Typhoeus::Hydra](lib/ruby-link-checker/typhoeus/hydra/checker.rb)

Fast link checker that uses [Typhoeus](https://typhoeus.github.io/). 

```ruby
require 'typhoeus'
require 'ruby-link-checker'

# create a new instance of a checker
checker = LinkChecker::Typhoeus::Hydra::Checker.new(
  hydra: {
    # lower than the Typhoeus default of 200, seems to start breaking around 50+
    max_concurrency: 25
  }
)

# log requests and response codes
checker.logger.level = Logger::INFO

links = [...] # array of URLs
links.each do |url|
  checker.check url
end

# examine failures as they come
checker.on :failure do |result|
  puts "FAIL: #{result.uri}: #{result.response.code}"
end    

# execute Hydra#run, will block until all requests have completed
checker.run

# examine results
checker.results.each_pair do |bucket, results|
  puts "#{bucket}: #{results.size}"
end
```

#### [LinkChecker::Net::HTTP](lib/ruby-link-checker/net/http/checker.rb)

Slow, sequential checker.

```ruby
require 'net/http'
require 'ruby-link-checker'

# create a new instance of a checker
checker = LinkChecker::Net::HTTP::Checker.new

# log requests and response codes
checker.logger.level = Logger::INFO

links = [...] # array of URLs
links.each do |url|
  checker.check url
end

# examine results
checker.results.each_pair do |bucket, results|
  puts "#{bucket}: #{results.size}"
end
```

### Options

#### Methods

By default checkers try a `HEAD` request, followed by a `GET` if `HEAD` fails. You can change this behavior by specifying other methods.

The following examples disables `GET` and only makes `HEAD` requests.

```ruby
checker = LinkChecker::Net::HTTP::Checker.new(methods: %w[HEAD])
```

#### Logger

Pass your own logger.

```ruby
checker = LinkChecker::Net::HTTP::Checker.new(logger: Logger.new(STDOUT))
```

#### User-Agent

Pass your own user-agent. Default is `Ruby Link Checker/x.y.z`.

```ruby
checker = LinkChecker::Net::HTTP::Checker.new(user_agent: 'Custom Agent/1.0')
```

### Global Configuration

All options can also be configured globally.

```ruby
LinkChecker.configure do |config|
  config.user_agent = 'Custom Agent/1.0'
  config.methods = ['HEAD', 'GET']
  config.logger = ::Logger.new(STDOUT)
end
```

### Events

Events enable processing of results as they become available.

```ruby
checker.on :result do |result|
  puts result
end
```

See [result.rb](lib/ruby-link-checker/result.rb) for available properties.

Checkers support the following events.

| Event    | Description                                                    |
|----------|----------------------------------------------------------------|
| :result  | A new result, any of sucess, failure, or error.                |
| :success | A valid URL, usually a 2xx response from the server.           |
| :failure | A failed URL, usually a 4xx or a 5xx response from the server. |
| :error   | An error, such as an invalid URL.                              |

## Contributing

You're encouraged to contribute to ruby-link-checker. See [CONTRIBUTING](CONTRIBUTING.md) for details.

## Copyright and License

Copyright (c) Daniel Doubrovkine and [Contributors](CHANGELOG.md).

This project is licensed under the [MIT License](LICENSE.md).
