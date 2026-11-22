### 0.6.0 (Next)

* [#31](https://github.com/dblock/ruby-link-checker/pull/31): Updated ruby-gem-release to 0.5.0 - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#38](https://github.com/dblock/ruby-link-checker/pull/38): Added `blocked_status_codes` (default `[401, 403, 429, 999]`) and `detect_challenges` (enabled by default, recognizes Cloudflare's `cf-mitigated: challenge`) to report links blocked by bot walls as `:blocked` instead of `:failure`; set `blocked_status_codes: []` and `detect_challenges: false` to restore the previous behavior - [@dblock](https://github.com/dblock).
* [#39](https://github.com/dblock/ruby-link-checker/pull/39): Added a `:complete` event published once per link with its final result and documented which events fire per attempt and which fire once per link - [@dblock](https://github.com/dblock).
* [#40](https://github.com/dblock/ruby-link-checker/pull/40): Added `max_concurrency_per_host` and `min_host_interval` to limit concurrent and back-to-back requests to the same host - [@dblock](https://github.com/dblock).
* [#42](https://github.com/dblock/ruby-link-checker/pull/42): Added `host_headers` to send headers to specific hosts, chosen per redirect hop so that credentials are not forwarded to other hosts - [@dblock](https://github.com/dblock).
* [#43](https://github.com/dblock/ruby-link-checker/pull/43): Added `result.redirects` and `result.permanent_redirect?` with the redirect hops that led to a final result, persisted in the cache - [@dblock](https://github.com/dblock).
* [#44](https://github.com/dblock/ruby-link-checker/pull/44): Added an optional `blocked_ttl` cache setting to reuse blocked results for a shorter period than successes - [@dblock](https://github.com/dblock).
* [#46](https://github.com/dblock/ruby-link-checker/pull/46): Added per-host exponential backoff for rate-limited (429) responses with `rate_limit_retries` (default `2`, `0` disables), `rate_limit_backoff`, `max_rate_limit_delay`, and `rate_limit_status_codes`, honoring `Retry-After` - [@dblock](https://github.com/dblock).
* [#47](https://github.com/dblock/ruby-link-checker/pull/47): Added a logo and wordmark, excluded from the gem package - [@dblock](https://github.com/dblock).
* [#48](https://github.com/dblock/ruby-link-checker/pull/48): Updated ruby-gem-release to 0.9.0, added Commonmarker for Markdown changelogs, and added a release dry run - [@dblock](https://github.com/dblock).
* [#49](https://github.com/dblock/ruby-link-checker/pull/49): Fixed loading the gem on Ruby 4.0 by declaring the `logger` dependency, and added a `Package` workflow that installs the built gem in a clean environment - [@dblock](https://github.com/dblock).
* [#50](https://github.com/dblock/ruby-link-checker/pull/50): Ignored URL fragments in deduplication and cache identity, so links that differ only by `#fragment` share one check - [@dblock](https://github.com/dblock).
* Your contribution here.

### 0.5.1 (2026/11/08)

* [#30](https://github.com/dblock/ruby-link-checker/pull/30): Updated ruby-gem-release to 0.3.1 - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#29](https://github.com/dblock/ruby-link-checker/pull/29): Removed accidentally tracked Bundler artifacts, ignored local Bundler configuration and installed gems, and restricted gem packaging to tracked files - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#28](https://github.com/dblock/ruby-link-checker/pull/28): Updated ruby-gem-release to 0.3.0 and removed the unsupported dry-run release input and instructions - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).

### 0.5.0 (2026/11/07)

* [#27](https://github.com/dblock/ruby-link-checker/pull/27): Avoided duplicate test and lint runs by checking pull requests and pushes to `main` only - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#26](https://github.com/dblock/ruby-link-checker/pull/26): Added ruby-gem-release automation with manual, dry-run-first releases and RubyGems Trusted Publishing - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#23](https://github.com/dblock/ruby-link-checker/pull/23): Fixed chained relative redirects, bounded redirect following with `max_redirects`, enabled plain HTTP in the Net::HTTP checker, and corrected retry documentation - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#24](https://github.com/dblock/ruby-link-checker/pull/24): Added transient-only retries, opt-in retry delays/backoff/jitter and `Retry-After` handling, transport error categories, and an Async concurrency limit - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#25](https://github.com/dblock/ruby-link-checker/pull/25): Added opt-in URL deduplication and atomic TTL-based success caching, preserving per-submission metadata and query values - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#8](https://github.com/dblock/ruby-link-checker/issues/8): Added `protocol` configuration option to `LinkChecker::Async::HTTP` to force HTTP/1 or HTTP/2 - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).

### 0.4.0 (2026/8/17)

* [#13](https://github.com/dblock/ruby-link-checker/pull/13): Fix `SystemStackError` caused by infinite recursion in `_handle_result` - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#14](https://github.com/dblock/ruby-link-checker/pull/14): Migrate Danger to use danger-pr-comment workflow - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#14](https://github.com/dblock/ruby-link-checker/pull/14): Removed Code Climate - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#15](https://github.com/dblock/ruby-link-checker/pull/15): Added Codecov - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#18](https://github.com/dblock/ruby-link-checker/pull/18): Added Ruby 4.0 to the CI test matrix - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#19](https://github.com/dblock/ruby-link-checker/pull/19): Added `LinkChecker::Async::HTTP`, a link checker based on [async-http](https://github.com/socketry/async-http) - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#19](https://github.com/dblock/ruby-link-checker/pull/19): Dropped support for Ruby < 3.3 - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#20](https://github.com/dblock/ruby-link-checker/pull/20): Added support for custom headers - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).
* [#21](https://github.com/dblock/ruby-link-checker/pull/21): Improved test coverage to 100% and fixed Danger dry_run failure by unpinning `danger-changelog` - [@dblock](https://github.com/dblock), [@Copilot](https://github.com/Copilot).

### 0.3.0 (2025-07-05)

* [#10](https://github.com/dblock/ruby-link-checker/pull/10): Add a space after `:` to help rendering in GHA - [@dblock](https://github.com/dblock).

### 0.2.0 (2023-04-03)

* [#5](https://github.com/dblock/ruby-link-checker/pull/5): Fixed false positive redirect loop - [@dblock](https://github.com/dblock).

### 0.1.0 (2023-04-02)

* Initial public release - [@dblock](https://github.com/dblock).
