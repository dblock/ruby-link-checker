# Upgrading ruby-link-checker

## Upgrading to 0.6.0

### Blocked Results

Links whose final response is 401, 403, 429, or 999, or carries a known bot challenge, such as Cloudflare's `cf-mitigated: challenge`, are now reported as blocked instead of failed. They publish `:blocked` instead of `:failure`, have `blocked? == true` and `failure? == false`, and are collected in `results[:blocked]`, a new key in the results hash.

If you fail a build on `:failure` or `results[:failure]`, decide whether blocked links should fail it too, and handle `:blocked` or subscribe to `:complete`, which fires once per link with any outcome. To restore the previous behavior, report blocked links as failures:

```ruby
LinkChecker.configure do |config|
  config.blocked_status_codes = []
  config.detect_challenges = false
end
```

See [Blocked Results](README.md#blocked-results) for details.

### Rate Limits

Rate-limited responses (429) are now retried up to twice by default, with exponential backoff per host that honors `Retry-After`, even when `retries` is `0`. A rate-limited link can take about 3 more seconds to report, and other links to the same host wait during the backoff. To restore the previous behavior, disable it:

```ruby
LinkChecker.configure do |config|
  config.rate_limit_retries = 0
end
```

See [Rate Limits](README.md#rate-limits) for details.

### Events

A new `:complete` event fires once per link with its final result. `:result` still fires for every attempt, including redirect hops and a failed `HEAD` before a `GET`. If you report links from `:result`, switch to `:complete` or the outcome events. See [Callbacks and Events](README.md#callbacks-and-events).

### Caching

The cache file format changed to store redirect hops and blocked results. Caches written by earlier versions are ignored and rewritten, so the first run after upgrading checks every link again. Links that differ only by `#fragment` now share one cache entry and one check.

### LinkChecker::Net::HTTP

`LinkChecker::Net::HTTP::Checker` now responds to `run`, which finishes a run, for example to [prune the cache](README.md#caching). Links are still checked as they are submitted, so calling `run` is optional unless you prune the cache automatically.

### Ruby 4.0

The gem now declares its `logger` dependency, which Ruby 4.0 no longer includes by default. Earlier versions failed to load on Ruby 4.0 unless another gem in the bundle depended on `logger`.
