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
  - [Passing Options](#passing-options)
  - [Checkers](#checkers)
    - [LinkChecker::Typhoeus::Hydra](#linkcheckertyphoeushydra)
    - [LinkChecker::Net::HTTP](#linkcheckernethttp)
  - [Options](#options)
    - [Retries](#retries)
    - [Results](#results)
    - [Methods](#methods)
    - [Logger](#logger)
    - [User-Agent](#user-agent)
  - [Global Configuration](#global-configuration)
  - [Callbacks and Events](#callbacks-and-events)
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

### Passing Options

You can pipe custom options through `check` and retrieve them in events as follows.

```ruby
checker.check 'https://www.example.org', { location: 'page.html' }

checker.on :success do |result|
  result.options # contains { location: 'page.html' }
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

# examine failures and errors as they come
checker.on :error, :failure do |result|
  puts "FAIL: #{result}"
end    

# execute Hydra#run, will block until all requests have completed
checker.run

# examine results
checker.results.each_pair do |bucket, results|
  puts "#{bucket}: #{results.size}"
end
```

You can pass `Typhoeus` timeout options into a new instance of a checker, or configure timeouts globally.

```ruby
LinkChecker::Typhoeus::Hydra.configure do |config|
  config.timeout = 5
  config.connecttimeout = 10
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

You can pass `Net::HTTP` timeout options into a new instance of a checker, or configure timeouts globally.

```ruby
LinkChecker::Net::HTTP.configure do |config|
  config.read_timeout = 5
  config.open_timeout = 10
end
```

### Options

#### Retries

By default link checkers do not retry. You can set a number of times to retry all errors and failures with `retries`.

```ruby
checker = LinkChecker::Net::HTTP::Checker.new(retry: 1)
```

#### Results

By default checkers collect results. 

```ruby
checker = LinkChecker::Net::HTTP::Checker.new(results: false)
...
checker.run

checker.results # => { error: [...], failure: [...], success: [...] }
```

You can disable this with `results: false`.

```ruby
checker = LinkChecker::Net::HTTP::Checker.new(results: false)
...
checker.run

checker.results # => nil
```

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

### Callbacks and Events

Events enable processing of results as they become available.

```ruby
checker.on :result do |result|
  puts result # any result
end

checker.on :error, :failure do |result|
  puts result # error or failure
end
```

Checkers support the following events.

| Event    | Description                                                    |
|----------|----------------------------------------------------------------|
| :retry   | A request is being retried on failure or error.                |
| :result  | A new result, any of success, failure, or error.               |
| :success | A valid URL, usually a 2xx response from the server.           |
| :failure | A failed URL, usually a 4xx or a 5xx response from the server. |
| :error   | An error, such as an invalid URL or a network timeout.         |

Events are called with results, which contain the following properties.

| Property          | Description                                                     |
|-------------------|-----------------------------------------------------------------|
| :url              | The original URL before redirects.                              |
| :result_url       | The last URL, different from `url` in case of redirects.        |
| :method           | The result HTTP method.                                         |
| :code             | HTTP error code.                                                |
| :request_headers  | Request headers.                                                |
| :redirect_to      | A redirect URL in case of redirects.                            |
| :error            | A raised error in case of errors.                               |

See [result.rb](lib/ruby-link-checker/result.rb) for more details.

## Contributing

You're encouraged to contribute to ruby-link-checker. See [CONTRIBUTING](CONTRIBUTING.md) for details.

## Copyright and License

Copyright (c) Daniel Doubrovkine and [Contributors](CHANGELOG.md).

This project is licensed under the [MIT License](LICENSE.md).
