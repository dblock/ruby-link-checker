shared_context 'a link checker' do
  context 'with redirects', :aggregate_failures do
    let(:checker) { described_class.new(methods: ['GET'], max_redirects: 2) }
    let(:url) { 'https://www.example.org/start' }
    let(:result) { checker.results.values.flatten.first }

    around do |example|
      VCR.turned_off { example.run }
    end

    it 'resolves each relative redirect against the current URL' do
      stub_request(:any, url).to_return(status: 302, headers: { 'Location' => '/nested/next' })
      stub_request(:any, 'https://www.example.org/nested/next').to_return(status: 302, headers: { 'Location' => 'final' })
      stub_request(:any, 'https://www.example.org/nested/final').to_return(status: 200)
      checker.check(url, location: 'page.html')
      checker.run if checker.respond_to?(:run)
      expect(result.uri.to_s).to eq(url)
      expect(result.result_uri.to_s).to eq('https://www.example.org/nested/final')
      expect(result.options).to eq(location: 'page.html')
    end

    it 'stops redirect chains at the configured limit' do
      stub_request(:any, url).to_return(status: 302, headers: { 'Location' => '/one' })
      stub_request(:any, 'https://www.example.org/one').to_return(status: 302, headers: { 'Location' => '/two' })
      stub_request(:any, 'https://www.example.org/two').to_return(status: 302, headers: { 'Location' => '/three' })
      checker.check(url)
      checker.run if checker.respond_to?(:run)
      expect(result.error).to be_a(LinkChecker::Errors::RedirectLimitError)
      expect(result.uri.to_s).to eq(url)
      expect(result.result_uri.to_s).to eq('https://www.example.org/two')
      expect(a_request(:any, 'https://www.example.org/three')).not_to have_been_made
    end

    it 'detects a redirect back to the original URL without requesting it again' do
      stub_request(:any, url).to_return(status: 302, headers: { 'Location' => '/one' })
      stub_request(:any, 'https://www.example.org/one').to_return(status: 302, headers: { 'Location' => url })
      checker.check(url)
      checker.run if checker.respond_to?(:run)
      expect(checker.results[:error].first.error).to be_a(LinkChecker::Errors::RedirectLoopError)
      expect(a_request(:any, url)).to have_been_made.once
    end

    it 'allows redirects to be disabled' do
      checker.max_redirects = 0
      stub_request(:any, url).to_return(status: 302, headers: { 'Location' => '/one' })
      checker.check(url)
      checker.run if checker.respond_to?(:run)
      expect(checker.results[:error].first.error).to be_a(LinkChecker::Errors::RedirectLimitError)
      expect(a_request(:any, 'https://www.example.org/one')).not_to have_been_made
    end
  end

  context 'with transient retries' do
    let(:checker_options) { {} }
    let(:checker) { described_class.new({ methods: ['GET'], retries: 2 }.merge(checker_options)) }
    let(:url) { 'https://www.example.org/retry' }

    around do |example|
      VCR.turned_off { example.run }
    end

    it 'retries service errors and preserves metadata' do
      stub_request(:get, url).to_return({ status: 503 }, { status: 200 })
      checker.check(url, location: 'page.html')
      checker.run if checker.respond_to?(:run)
      expect(checker.results[:success].first.options).to eq(location: 'page.html')
      expect(a_request(:get, url)).to have_been_made.twice
    end

    it 'does not retry permanent HTTP failures' do
      stub_request(:get, url).to_return(status: 404)
      checker.check(url)
      checker.run if checker.respond_to?(:run)
      expect(checker.results[:failure].first.code).to eq(404)
      expect(a_request(:get, url)).to have_been_made.once
    end

    it 'retries timeouts and reports a timeout category' do
      stub_request(:get, url).to_timeout
      checker.check(url)
      checker.run if checker.respond_to?(:run)
      expect(checker.results[:error].first.error_type).to eq(:timeout)
      expect(a_request(:get, url)).to have_been_made.times(3)
    end

    it 'does not retry malformed URLs' do
      checker.check('\/invalid-url')
      checker.run if checker.respond_to?(:run)
      expect(checker.results[:error].first.error_type).to eq(:other)
      expect(checker.results[:error].size).to eq(1)
    end

    context 'with a configured delay and backoff' do
      let(:checker_options) { { retry_after: 0.005, retry_backoff: 2 } }

      it 'waits before each retry without changing the retry budget' do
        stub_request(:get, url).to_return({ status: 503 }, { status: 503 }, { status: 200 })
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        checker.check(url)
        checker.run if checker.respond_to?(:run)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        expect(elapsed).to be >= 0.015
        expect(a_request(:get, url)).to have_been_made.times(3)
        expect(checker.results[:success].size).to eq(1)
      end
    end

    context 'with Retry-After enabled' do
      let(:checker_options) { { respect_retry_after: true, max_retry_delay: 0.005 } }

      it 'honors a bounded server delay' do
        stub_request(:get, url).to_return({ status: 503, headers: { 'Retry-After' => '5' } }, { status: 200 })
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        checker.check(url)
        checker.run if checker.respond_to?(:run)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        expect(elapsed).to be >= 0.005
        expect(elapsed).to be < 1
        expect(checker.results[:success].size).to eq(1)
      end

      it 'accepts HTTP dates' do
        stub_request(:get, url).to_return(
          { status: 503, headers: { 'Retry-After' => (Time.now + 60).httpdate } }, { status: 200 }
        )
        checker.check(url)
        checker.run if checker.respond_to?(:run)
        expect(checker.results[:success].size).to eq(1)
      end

      it 'ignores invalid server delays' do
        stub_request(:get, url).to_return({ status: 503, headers: { 'Retry-After' => 'invalid' } }, { status: 200 })
        checker.check(url)
        checker.run if checker.respond_to?(:run)
        expect(checker.results[:success].size).to eq(1)
      end
    end
  end

  context 'with deduplication' do
    let(:checker) { described_class.new(methods: ['GET'], deduplicate: true) }
    let(:url) { 'https://www.example.org/' }

    around do |example|
      VCR.turned_off { example.run }
    end

    it 'checks once and preserves metadata for every submission' do
      stub_request(:any, url).to_return(status: 200)
      checker.check(url, location: 'one.html')
      checker.check(url, location: 'two.html')
      checker.run if checker.respond_to?(:run)
      expect(a_request(:any, url)).to have_been_made.once
      expect(checker.results[:success].map(&:options)).to eq([{ location: 'one.html' }, { location: 'two.html' }])
      expect(checker.results[:success].map(&:uri)).to eq([URI(url), URI(url)])
    end

    it 'rechecks failures instead of retaining them' do
      stub_request(:any, url).to_return({ status: 404 }, { status: 200 })
      checker.check(url)
      checker.run if checker.respond_to?(:run)
      checker.check(url)
      checker.run if checker.respond_to?(:run)
      expect(a_request(:any, url)).to have_been_made.twice
      expect(checker.results[:failure].size).to eq(1)
      expect(checker.results[:success].size).to eq(1)
    end

    it 'shares one check between links that differ only by fragment' do
      stub_request(:any, url).to_return(status: 200)
      checker.check("#{url}#one", location: 'one.html')
      checker.check("#{url}#two", location: 'two.html')
      checker.run if checker.respond_to?(:run)
      expect(a_request(:any, url)).to have_been_made.once
      expect(checker.results[:success].map { |result| result.uri.fragment }).to eq %w[one two]
      expect(checker.results[:success].map { |result| result.result_uri.fragment }).to eq %w[one two]
    end

    it 'keeps query values distinct' do
      stub_request(:any, "#{url}?id=1").to_return(status: 200)
      stub_request(:any, "#{url}?id=2").to_return(status: 404)
      checker.check("#{url}?id=1")
      checker.check("#{url}?id=2")
      checker.run if checker.respond_to?(:run)
      expect(checker.results[:success].first.uri.query).to eq('id=1')
      expect(checker.results[:failure].first.uri.query).to eq('id=2')
    end

    it 'includes headers in request identity' do
      stub_request(:any, url).to_return(status: 200)
      checker.check(url)
      checker.run if checker.respond_to?(:run)
      checker.headers = { 'Accept' => 'text/html' }
      checker.check(url)
      checker.run if checker.respond_to?(:run)
      expect(a_request(:any, url)).to have_been_made.twice
    end

    context 'without result collection' do
      let(:checker) { described_class.new(methods: ['GET'], deduplicate: true, results: false) }

      it 'still delivers results to every subscriber' do
        completed = []
        stub_request(:any, url).to_return(status: 200)
        checker.on(:success) { |result| completed << result.options }
        checker.check(url, location: 'one.html')
        checker.check(url, location: 'two.html')
        checker.run if checker.respond_to?(:run)
        expect(completed).to eq([{ location: 'one.html' }, { location: 'two.html' }])
        expect(checker.results).to be_nil
      end
    end
  end

  context 'with persistent caching' do
    let(:directory) { Dir.mktmpdir('link-checker-spec-') }
    let(:cache_options) { { file: File.join(directory, 'cache.json'), ttl: 60 } }
    let(:checker) { described_class.new(methods: ['GET'], cache: cache_options) }
    let(:next_checker) { described_class.new(methods: ['GET'], cache: cache_options) }
    let(:url) { 'https://www.example.org/' }

    around do |example|
      VCR.turned_off { example.run }
    end

    after do
      FileUtils.remove_entry(directory)
    end

    it 'reuses a success across checker instances with fresh metadata' do
      stub_request(:any, url).to_return(status: 200)
      checker.check(url, location: 'one.html')
      checker.run if checker.respond_to?(:run)
      next_checker.check(url, location: 'two.html')
      next_checker.run if next_checker.respond_to?(:run)
      expect(next_checker.results[:success].first.cached?).to be true
      expect(next_checker.results[:success].first.options).to eq(location: 'two.html')
      expect(a_request(:any, url)).to have_been_made.once
    end

    it 'reuses a cached success for another fragment of the same URL' do
      stub_request(:any, url).to_return(status: 200)
      checker.check("#{url}#one")
      checker.run if checker.respond_to?(:run)
      next_checker.check("#{url}#two")
      next_checker.run if next_checker.respond_to?(:run)
      result = next_checker.results[:success].first
      expect([result.cached?, result.uri.fragment, result.result_uri.fragment]).to eq [true, 'two', 'two']
      expect(a_request(:any, url)).to have_been_made.once
    end

    context 'with pruning' do
      let(:cache_options) { { file: File.join(directory, 'cache.json'), ttl: 60, prune: true } }

      def cached_entries
        JSON.parse(File.read(cache_options[:file]))['entries'].size
      end

      def cache_two_links
        other_url = 'https://www.example.org/other'
        stub_request(:any, url).to_return(status: 200)
        stub_request(:any, other_url).to_return(status: 200)
        [url, other_url].each { |link| checker.check(link) }
        checker.run if checker.respond_to?(:run)
      end

      it 'drops entries that a run did not use' do
        cache_two_links
        expect(cached_entries).to eq 2
        next_checker.check(url)
        next_checker.run
        expect(cached_entries).to eq 1
        expect(next_checker.results[:success].first.cached?).to be true
      end

      it 'keeps entries without pruning' do
        cache_two_links
        unpruned = described_class.new(methods: ['GET'], cache: cache_options.merge(prune: false))
        unpruned.check(url)
        unpruned.run
        expect(cached_entries).to eq 2
        expect(unpruned.prune_cache!).to eq 1
        expect(cached_entries).to eq 1
      end
    end

    it 'does not persist failed checks' do
      stub_request(:any, url).to_return({ status: 404 }, { status: 200 })
      checker.check(url)
      checker.run if checker.respond_to?(:run)
      next_checker.check(url)
      next_checker.run if next_checker.respond_to?(:run)
      expect(next_checker.results[:success].first.cached?).to be false
      expect(a_request(:any, url)).to have_been_made.twice
    end
  end

  context 'with blocked results', :aggregate_failures do
    let(:checker_options) { {} }
    let(:checker) { described_class.new(checker_options) }
    let(:url) { 'https://www.example.org/blocked' }
    let(:events) { [] }

    around do |example|
      VCR.turned_off { example.run }
    end

    before do
      checker.on { |event, result| events << [event, result.method, result.code] }
    end

    def run_check(target = url)
      checker.check(target, location: 'page.html')
      checker.run if checker.respond_to?(:run)
    end

    it 'reports a blocked status after the HEAD to GET fallback' do
      stub_request(:any, url).to_return(status: 403)
      run_check
      result = checker.results[:blocked].first
      expect(result.blocked?).to be true
      expect(result.failure?).to be false
      expect(result.success?).to be false
      expect(result.method).to eq 'GET'
      expect(result.options).to eq(location: 'page.html')
    end

    it 'publishes blocked instead of failure' do
      stub_request(:any, url).to_return(status: 403)
      run_check
      expect(checker.results[:blocked].first.to_s).to include('BLOCKED (403)')
      expect(checker.results[:failure]).to be_empty
      expect(events.map(&:first)).to eq(%i[result result blocked complete])
    end

    it 'reports a failure when GET returns a status that is not blocked' do
      stub_request(:head, url).to_return(status: 403)
      stub_request(:get, url).to_return(status: 404)
      run_check
      expect(checker.results[:failure].first.code).to eq 404
      expect(checker.results[:failure].first.blocked?).to be false
      expect(checker.results[:blocked]).to be_empty
    end

    it 'supports non-standard status codes' do
      stub_request(:any, url).to_return(status: 999)
      run_check
      expect(checker.results[:blocked].first.code).to eq 999
    end

    it 'reports a blocked redirect target' do
      stub_request(:any, url).to_return(status: 301, headers: { 'Location' => '/login' })
      stub_request(:any, 'https://www.example.org/login').to_return(status: 401)
      run_check
      expect(checker.results[:blocked].first.result_uri.to_s).to eq 'https://www.example.org/login'
    end

    context 'with retries' do
      let(:checker_options) { { methods: ['GET'], retries: 1, rate_limit_retries: 0 } }

      it 'reports blocked only after retries are exhausted' do
        stub_request(:get, url).to_return(status: 429)
        run_check
        expect(a_request(:get, url)).to have_been_made.twice
        expect(events.map(&:first)).to eq(%i[result retry result blocked complete])
      end

      it 'reports success when a retry succeeds' do
        stub_request(:get, url).to_return({ status: 429 }, { status: 200 })
        run_check
        expect(checker.results[:success].size).to eq 1
        expect(checker.results[:blocked]).to be_empty
      end
    end

    context 'with deduplication' do
      let(:checker_options) { { methods: ['GET'], deduplicate: true } }

      it 'delivers blocked results to every submission and rechecks later submissions' do
        stub_request(:get, url).to_return(status: 403)
        checker.check(url, location: 'one.html')
        checker.check(url, location: 'two.html')
        checker.run if checker.respond_to?(:run)
        expect(checker.results[:blocked].map(&:options)).to eq([{ location: 'one.html' }, { location: 'two.html' }])
        WebMock::RequestRegistry.instance.reset!
        run_check
        expect(a_request(:get, url)).to have_been_made.once
        expect(checker.results[:blocked].size).to eq 3
      end
    end

    context 'with a persistent cache' do
      let(:directory) { Dir.mktmpdir('link-checker-spec-') }
      let(:checker_options) { { methods: ['GET'], cache: { file: File.join(directory, 'cache.json'), ttl: 60 } } }

      after do
        FileUtils.remove_entry(directory)
      end

      it 'does not cache blocked results' do
        stub_request(:get, url).to_return(status: 403)
        run_check
        described_class.new(checker_options).tap do |next_checker|
          next_checker.check(url)
          next_checker.run if next_checker.respond_to?(:run)
        end
        expect(a_request(:get, url)).to have_been_made.twice
      end
    end

    context 'with a blocked TTL' do
      let(:directory) { Dir.mktmpdir('link-checker-spec-') }
      let(:checker_options) do
        { methods: ['GET'], cache: { file: File.join(directory, 'cache.json'), ttl: 60, blocked_ttl: 30 } }
      end

      after do
        FileUtils.remove_entry(directory)
      end

      def recheck(options = checker_options)
        next_checker = described_class.new({ blocked_status_codes: [403] }.merge(options))
        next_checker.check(url, location: 'next.html')
        next_checker.run if next_checker.respond_to?(:run)
        next_checker
      end

      it 'reuses a blocked result within the blocked TTL' do
        stub_request(:get, url).to_return(status: 403)
        run_check
        next_checker = recheck
        result = next_checker.results[:blocked].first
        expect([result.cached?, result.blocked?, result.failure?, result.code]).to eq [true, true, false, 403]
        expect(result.options).to eq(location: 'next.html')
        expect(a_request(:get, url)).to have_been_made.once
      end

      it 'rechecks a blocked result after the blocked TTL' do
        stub_request(:get, url).to_return(status: 403)
        run_check
        allow(Time).to receive(:now).and_return(Time.now + 31)
        expect(recheck.results[:blocked].first.cached?).to be false
        expect(a_request(:get, url)).to have_been_made.twice
      end

      it 'rechecks when the cached status code is no longer blocked' do
        stub_request(:get, url).to_return(status: 403)
        run_check
        next_checker = recheck(checker_options.merge(blocked_status_codes: [429]))
        expect(next_checker.results[:failure].first.code).to eq 403
        expect(a_request(:get, url)).to have_been_made.twice
      end

      it 'reuses a cached challenge only while challenges are detected' do
        stub_request(:get, url).to_return(status: 503, headers: { 'cf-mitigated' => 'challenge' })
        run_check
        cached = recheck.results[:blocked].first
        expect([cached.cached?, cached.challenge]).to eq [true, 'Cloudflare']
        expect(cached.reason).to eq 'Cloudflare challenge (HTTP 503)'
        expect(recheck(checker_options.merge(detect_challenges: false)).results[:failure].size).to eq 1
        expect(a_request(:get, url)).to have_been_made.twice
      end

      it 'never caches failures' do
        stub_request(:get, url).to_return(status: 404)
        run_check
        recheck
        expect(a_request(:get, url)).to have_been_made.twice
      end
    end

    context 'without blocked status codes' do
      let(:checker) { described_class.new(methods: ['GET'], blocked_status_codes: []) }

      it 'reports a failure' do
        stub_request(:get, url).to_return(status: 403)
        run_check
        expect(checker.results[:failure].first.code).to eq 403
        expect(checker.results[:blocked]).to be_empty
      end
    end

    context 'with default challenge detection' do
      let(:checker) { described_class.new(methods: ['GET'], blocked_status_codes: []) }

      it 'reports a Cloudflare challenge as blocked' do
        stub_request(:get, url).to_return(status: 403, headers: { 'cf-mitigated' => 'challenge' })
        run_check
        expect(checker.results[:blocked].first.code).to eq 403
      end

      it 'keeps an ordinary 403 a failure' do
        stub_request(:get, url).to_return(status: 403)
        run_check
        expect(checker.results[:failure].first.code).to eq 403
      end
    end

    context 'with a challenge header and detection disabled' do
      let(:checker) { described_class.new(methods: ['GET'], blocked_status_codes: [], detect_challenges: false) }

      it 'reports a failure' do
        stub_request(:get, url).to_return(status: 403, headers: { 'cf-mitigated' => 'challenge' })
        run_check
        expect(checker.results[:failure].size).to eq 1
      end
    end

    it 'never reports errors as blocked' do
      stub_request(:any, url).to_timeout
      run_check
      expect(checker.results[:error].size).to eq 1
      expect(checker.results[:blocked]).to be_empty
    end
  end

  context 'event order', :aggregate_failures do
    let(:checker_options) { { methods: ['GET'] } }
    let(:checker) { described_class.new(checker_options) }
    let(:url) { 'https://www.example.org/events' }
    let(:events) { [] }

    around do |example|
      VCR.turned_off { example.run }
    end

    before do
      checker.on { |event, result| events << [event, result.method, result.code] }
    end

    def run_check
      checker.check(url)
      checker.run if checker.respond_to?(:run)
    end

    it 'publishes a result per redirect hop and one outcome for a redirect chain' do
      stub_request(:get, url).to_return(status: 301, headers: { 'Location' => '/next' })
      stub_request(:get, 'https://www.example.org/next').to_return(status: 302, headers: { 'Location' => '/final' })
      stub_request(:get, 'https://www.example.org/final').to_return(status: 200)
      run_check
      expect(events.map { |event, _method, code| [event, code] }).to eq(
        [[:result, 301], [:redirect, 301], [:result, 302], [:redirect, 302]] +
        [[:result, 200], [:success, 200], [:complete, 200]]
      )
    end

    context 'with HEAD and GET' do
      let(:checker_options) { { methods: %w[HEAD GET] } }

      it 'publishes a result per method and one outcome for a fallback' do
        stub_request(:head, url).to_return(status: 405)
        stub_request(:get, url).to_return(status: 200)
        run_check
        expect(events).to eq(
          [[:result, 'HEAD', 405], [:result, 'GET', 200], [:success, 'GET', 200], [:complete, 'GET', 200]]
        )
      end

      it 'publishes the documented events for a redirect followed by a fallback' do
        stub_request(:any, url).to_return(status: 301, headers: { 'Location' => '/moved' })
        stub_request(:head, 'https://www.example.org/moved').to_return(status: 405)
        stub_request(:get, 'https://www.example.org/moved').to_return(status: 200)
        run_check
        expect(events).to eq(
          [[:result, 'HEAD', 301], [:redirect, 'HEAD', 301], [:result, 'HEAD', 405]] +
          [[:result, 'GET', 301], [:redirect, 'GET', 301], [:result, 'GET', 200]] +
          [[:success, 'GET', 200], [:complete, 'GET', 200]]
        )
      end

      it 'publishes one failure when both methods fail' do
        stub_request(:any, url).to_return(status: 404)
        run_check
        expect(events).to eq(
          [[:result, 'HEAD', 404], [:result, 'GET', 404], [:failure, 'GET', 404], [:complete, 'GET', 404]]
        )
      end
    end

    context 'with retries' do
      let(:checker_options) { { methods: ['GET'], retries: 1 } }

      it 'publishes a retry between attempts' do
        stub_request(:get, url).to_return({ status: 503 }, { status: 200 })
        run_check
        expect(events.map(&:first)).to eq(%i[result retry result success complete])
      end
    end

    it 'publishes complete once for an error' do
      stub_request(:get, url).to_timeout
      run_check
      expect(events.map(&:first)).to eq(%i[result error complete])
    end

    it 'publishes complete once for a blocked result' do
      checker.blocked_status_codes = [403]
      stub_request(:get, url).to_return(status: 403)
      run_check
      expect(events.map(&:first)).to eq(%i[result blocked complete])
    end

    it 'does not collect complete events in results' do
      stub_request(:get, url).to_return(status: 200)
      run_check
      expect(checker.results.keys).to eq(%i[error failure success blocked])
    end

    context 'with a persistent cache' do
      let(:directory) { Dir.mktmpdir('link-checker-spec-') }
      let(:checker_options) { { methods: ['GET'], cache: { file: File.join(directory, 'cache.json'), ttl: 60 } } }

      after do
        FileUtils.remove_entry(directory)
      end

      it 'publishes result, success, and complete for a cache hit' do
        stub_request(:get, url).to_return(status: 200)
        described_class.new(checker_options).tap do |first_checker|
          first_checker.check(url)
          first_checker.run if first_checker.respond_to?(:run)
        end
        run_check
        expect(events.map(&:first)).to eq(%i[result success complete])
      end
    end
  end

  context 'with host headers', :aggregate_failures do
    let(:host_headers) { { 'www.example.org' => { 'Accept' => 'text/html' } } }
    let(:checker) { described_class.new(methods: ['GET'], headers: { 'DNT' => '1' }, host_headers: host_headers) }
    let(:url) { 'https://www.example.org/page' }

    around do |example|
      VCR.turned_off { example.run }
    end

    def run_check(target = url)
      checker.check(target)
      checker.run if checker.respond_to?(:run)
    end

    it 'adds headers for a matching host on top of global headers' do
      stub_request(:get, url).to_return(status: 200)
      run_check
      expect(a_request(:get, url).with(headers: { 'Accept' => 'text/html', 'DNT' => '1' })).to have_been_made
    end

    it 'does not add headers for other hosts' do
      stub_request(:get, 'https://www.example.com/').to_return(status: 200)
      run_check('https://www.example.com/')
      expect(a_request(:get, 'https://www.example.com/').with(headers: { 'DNT' => '1' })).to have_been_made
      expect(a_request(:get, 'https://www.example.com/').with(headers: { 'Accept' => 'text/html' })).not_to have_been_made
    end

    context 'with a pattern' do
      let(:host_headers) { { /\.example\.org\z/ => { 'Cookie' => 'consent=1' } } }

      it 'matches hosts with a regular expression' do
        stub_request(:get, url).to_return(status: 200)
        run_check
        expect(a_request(:get, url).with(headers: { 'Cookie' => 'consent=1' })).to have_been_made
      end
    end

    context 'with overrides' do
      let(:host_headers) { { 'WWW.EXAMPLE.ORG' => { 'dnt' => '0', 'user-agent' => 'Browser/1.0' } } }

      it 'replaces global headers and the user-agent case-insensitively' do
        stub_request(:get, url).to_return(status: 200)
        run_check
        expect(a_request(:get, url).with(headers: { 'DNT' => '0', 'User-Agent' => 'Browser/1.0' })).to have_been_made
      end
    end

    context 'with a redirect to another host' do
      let(:host_headers) { { 'api.example.org' => { 'Authorization' => 'token secret' } } }
      let(:url) { 'https://api.example.org/repo' }
      let(:target) { 'https://www.example.com/repo' }

      it 'does not forward host headers to the other host' do
        stub_request(:get, url).to_return(status: 301, headers: { 'Location' => target })
        stub_request(:get, target).to_return(status: 200)
        run_check
        expect(a_request(:get, url).with(headers: { 'Authorization' => 'token secret' })).to have_been_made
        expect(a_request(:get, target).with(headers: { 'DNT' => '1' })).to have_been_made
        expect(a_request(:get, target).with(headers: { 'Authorization' => 'token secret' })).not_to have_been_made
      end
    end

    context 'with deduplication' do
      let(:checker) { described_class.new(methods: ['GET'], deduplicate: true, host_headers: host_headers) }

      it 'includes host headers in request identity' do
        stub_request(:get, url).to_return(status: 200)
        run_check
        checker.host_headers = { 'www.example.org' => { 'Accept' => 'application/json' } }
        run_check
        expect(a_request(:get, url)).to have_been_made.twice
      end
    end
  end

  context 'with redirect chains', :aggregate_failures do
    let(:checker_options) { { methods: ['GET'] } }
    let(:checker) { described_class.new(checker_options) }
    let(:url) { 'https://www.example.org/old' }
    let(:result) { checker.results.values.flatten.first }

    around do |example|
      VCR.turned_off { example.run }
    end

    def run_check
      checker.check(url)
      checker.run if checker.respond_to?(:run)
    end

    it 'exposes the hops on the final result' do
      stub_request(:get, url).to_return(status: 301, headers: { 'Location' => '/moved' })
      stub_request(:get, 'https://www.example.org/moved').to_return(status: 302, headers: { 'Location' => 'new' })
      stub_request(:get, 'https://www.example.org/new').to_return(status: 200)
      run_check
      expect(result.redirects.map(&:code)).to eq [301, 302]
      expect(result.redirects.map { |hop| hop.uri.to_s }).to eq [url, 'https://www.example.org/moved']
      expect(result.redirects.map { |hop| hop.to.to_s }).to eq ['https://www.example.org/moved', 'https://www.example.org/new']
      expect(result.permanent_redirect?).to be true
    end

    it 'does not report temporary redirects as permanent' do
      stub_request(:get, url).to_return(status: 307, headers: { 'Location' => '/new' })
      stub_request(:get, 'https://www.example.org/new').to_return(status: 200)
      run_check
      expect(result.redirects.map(&:code)).to eq [307]
      expect(result.permanent_redirect?).to be false
    end

    it 'has no hops without redirects' do
      stub_request(:get, url).to_return(status: 404)
      run_check
      expect(result.redirects).to eq []
      expect(result.permanent_redirect?).to be false
    end

    it 'includes the hops that led to a redirect loop' do
      stub_request(:get, url).to_return(status: 308, headers: { 'Location' => '/new' })
      stub_request(:get, 'https://www.example.org/new').to_return(status: 302, headers: { 'Location' => url })
      run_check
      expect(result.error).to be_a LinkChecker::Errors::RedirectLoopError
      expect(result.redirects.map(&:code)).to eq [308, 302]
    end

    context 'with HEAD and GET' do
      let(:checker_options) { { methods: %w[HEAD GET] } }

      it 'only reports the hops of the final attempt' do
        stub_request(:head, url).to_return(status: 301, headers: { 'Location' => '/head' })
        stub_request(:head, 'https://www.example.org/head').to_return(status: 405)
        stub_request(:get, url).to_return(status: 302, headers: { 'Location' => '/get' })
        stub_request(:get, 'https://www.example.org/get').to_return(status: 200)
        run_check
        expect(result.method).to eq 'GET'
        expect(result.redirects.map { |hop| [hop.code, hop.to.to_s] }).to eq [[302, 'https://www.example.org/get']]
      end
    end

    context 'with a persistent cache' do
      let(:directory) { Dir.mktmpdir('link-checker-spec-') }
      let(:checker_options) { { methods: ['GET'], cache: { file: File.join(directory, 'cache.json'), ttl: 60 } } }

      after do
        FileUtils.remove_entry(directory)
      end

      def prime_cache
        first_checker = described_class.new(checker_options)
        first_checker.check(url)
        first_checker.run if first_checker.respond_to?(:run)
      end

      it 'restores the hops of a cached success' do
        stub_request(:get, url).to_return(status: 301, headers: { 'Location' => '/new' })
        stub_request(:get, 'https://www.example.org/new').to_return(status: 200)
        prime_cache
        run_check
        expect(result.cached?).to be true
        expect(result.redirects.map(&:code)).to eq [301]
        expect(result.permanent_redirect?).to be true
      end
    end
  end

  context 'with rate limiting', :aggregate_failures do
    let(:checker_options) { { methods: ['GET'], rate_limit_backoff: 0.01 } }
    let(:checker) { described_class.new(checker_options) }
    let(:url) { 'https://www.example.org/limited' }
    let(:events) { [] }

    around do |example|
      VCR.turned_off { example.run }
    end

    before do
      checker.on { |event, result| events << [event, result.code] }
    end

    def run_check
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      checker.check(url)
      checker.run if checker.respond_to?(:run)
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    end

    it 'retries rate limited responses by default' do
      stub_request(:get, url).to_return({ status: 429 }, { status: 200 })
      run_check
      expect(checker.results[:success].size).to eq 1
      expect(events.map(&:first)).to eq(%i[result retry result success complete])
    end

    it 'backs off exponentially' do
      stub_request(:get, url).to_return({ status: 429 }, { status: 429 }, { status: 200 })
      checker.rate_limit_backoff = 0.02
      expect(run_check).to be >= 0.06
      expect(a_request(:get, url)).to have_been_made.times(3)
    end

    it 'reports blocked after the rate limit retries' do
      stub_request(:get, url).to_return(status: 429)
      run_check
      expect(a_request(:get, url)).to have_been_made.times(3)
      expect(checker.results[:blocked].first.code).to eq 429
    end

    it 'falls back to general retries after the rate limit retries' do
      stub_request(:get, url).to_return(status: 429)
      checker.rate_limit_retries = 1
      checker.retries = 1
      run_check
      expect(a_request(:get, url)).to have_been_made.times(3)
    end

    it 'honors and caps Retry-After' do
      stub_request(:get, url).to_return({ status: 429, headers: { 'Retry-After' => '5' } }, { status: 200 })
      checker.max_rate_limit_delay = 0.05
      elapsed = run_check
      expect(elapsed).to be >= 0.05
      expect(elapsed).to be < 1
    end

    it 'retries custom rate limit statuses' do
      stub_request(:get, url).to_return({ status: 503 }, { status: 200 })
      checker.rate_limit_status_codes = [503]
      run_check
      expect(checker.results[:success].size).to eq 1
    end

    context 'when disabled' do
      let(:checker_options) { { methods: ['GET'], rate_limit_retries: 0 } }

      it 'does not retry' do
        stub_request(:get, url).to_return({ status: 429 }, { status: 200 })
        run_check
        expect(a_request(:get, url)).to have_been_made.once
        expect(checker.results[:blocked].first.code).to eq 429
      end
    end
  end

  context 'with result summaries', :aggregate_failures do
    let(:checker) { described_class.new(methods: ['GET'], max_redirects: 3) }
    let(:url) { 'https://www.example.org/summary' }
    let(:result) { checker.results.values.flatten.first }
    let(:redirected_summary) do
      {
        url: url, result_url: 'https://www.example.org/moved', method: 'GET', code: 200,
        outcome: :success, reason: 'HTTP 200', permanent_redirect: true,
        redirects: [{ url: url, code: 301, to: 'https://www.example.org/moved' }],
        blocked: false, challenge: nil, cached: false, error: nil, error_type: nil, options: { location: 'page.html' }
      }
    end

    around do |example|
      VCR.turned_off { example.run }
    end

    def run_check(target = url)
      checker.check(target, location: 'page.html')
      checker.run if checker.respond_to?(:run)
    end

    it 'summarizes a success after a permanent redirect' do
      stub_request(:get, url).to_return(status: 301, headers: { 'Location' => '/moved' })
      stub_request(:get, 'https://www.example.org/moved').to_return(status: 200)
      run_check
      expect(result.to_h).to eq(redirected_summary)
      expect(JSON.parse(JSON.generate(result.to_h))['reason']).to eq 'HTTP 200'
    end

    it 'explains failures with the status' do
      stub_request(:get, url).to_return(status: 404)
      run_check
      expect([result.outcome, result.reason, result.to_h[:code]]).to eq [:failure, 'HTTP 404', 404]
    end

    it 'explains blocked statuses and challenges' do
      stub_request(:get, url).to_return(status: 403)
      stub_request(:get, "#{url}/challenge").to_return(status: 503, headers: { 'cf-mitigated' => 'challenge' })
      run_check
      run_check("#{url}/challenge")
      expect(checker.results[:blocked].map(&:reason)).to eq ['HTTP 403', 'Cloudflare challenge (HTTP 503)']
      expect(checker.results[:blocked].map { |blocked| blocked.to_h[:challenge] }).to eq [nil, 'Cloudflare']
    end

    it 'names challenges on failures when they are not reported as blocked' do
      checker.detect_challenges = false
      checker.blocked_status_codes = []
      stub_request(:get, url).to_return(status: 403, headers: { 'cf-mitigated' => 'challenge' })
      run_check
      expect([result.outcome, result.to_h[:challenge]]).to eq [:failure, 'Cloudflare']
      expect(result.reason).to eq 'Cloudflare challenge (HTTP 403)'
    end

    it 'explains timeouts' do
      stub_request(:get, url).to_timeout
      run_check
      expect([result.outcome, result.reason]).to eq [:error, 'Timeout']
      expect(result.to_h.values_at(:code, :error_type)).to eq [nil, :timeout]
    end

    it 'explains redirect loops and limits' do
      stub_request(:get, url).to_return(status: 302, headers: { 'Location' => url })
      stub_request(:get, "#{url}/far").to_return(status: 302, headers: { 'Location' => "#{url}/far/1" })
      stub_request(:get, %r{/far/\d}).to_return { |request| { status: 302, headers: { 'Location' => "#{request.uri}1" } } }
      run_check
      run_check("#{url}/far")
      expect(checker.results[:error].map(&:reason)).to eq ['Redirect loop', 'Too many redirects']
    end

    it 'explains invalid URLs' do
      run_check('\/invalid-url')
      expect([result.reason, result.to_h[:url]]).to eq ['Invalid URL', '\/invalid-url']
    end
  end

  context 'default' do
    subject do
      described_class.new
    end

    it 'has a default user-agent' do
      expect(subject.user_agent).to eq "Ruby Link Checker/#{LinkChecker::VERSION}"
    end

    it 'has no default headers' do
      expect(subject.headers).to eq({})
      expect(subject.host_headers).to eq({})
    end
  end

  context 'user-agent' do
    subject do
      described_class.new(user_agent: 'user/agent')
    end

    it 'updates user-agent' do
      expect(subject.user_agent).to eq 'user/agent'
    end
  end

  context 'headers' do
    subject do
      described_class.new(headers: { 'DNT' => '1' })
    end

    it 'updates headers' do
      expect(subject.headers).to eq('DNT' => '1')
    end
  end

  context 'check' do
    let(:url) { 'https://www.example.org' }

    include_context 'with result'

    context 'with metadata' do
      before do
        subject.check(url, foo: 'bar')
      end

      context 'GET' do
        subject do
          described_class.new(methods: ['GET'])
        end

        context 'check' do
          context '200', vcr: { cassette_name: '200' } do
            it 'passes metadata' do
              expect(result.options).to eq(foo: 'bar')
            end
          end

          context '404', vcr: { cassette_name: '404' } do
            it 'passes metadata' do
              expect(result.options).to eq(foo: 'bar')
            end
          end

          context 'error', vcr: { cassette_name: '404' } do
            let(:url) { '\/invalid-url' }

            it 'passes metadata' do
              expect(result.options).to eq(foo: 'bar')
            end
          end

          context 'a redirect loop', vcr: { cassette_name: '301+301' } do
            it 'passes metadata' do
              expect(result.options).to eq(foo: 'bar')
            end
          end
        end
      end
    end

    context 'without results' do
      before do
        subject.check(url, foo: 'bar')
      end

      context 'GET' do
        subject do
          described_class.new(results: false, methods: ['GET'])
        end

        context 'check' do
          context 'a valid URI that returns a 200', vcr: { cassette_name: '200' } do
            it 'passes metadata' do
              expect(subject.results).to be_nil
            end
          end
        end
      end
    end

    context 'without metadata' do
      before do
        subject.check(url)
      end

      context 'GET' do
        subject do
          described_class.new(methods: ['GET'])
        end

        context 'check' do
          context 'a valid URI that returns a 200', vcr: { cassette_name: '200' } do
            it 'sets user agent' do
              expect(result.request_headers['User-Agent']).to eq "Ruby Link Checker/#{LinkChecker::VERSION}"
            end

            it 'returns all metadata' do
              expect(result.options).to eq({})
            end

            context 'with custom headers' do
              subject do
                described_class.new(methods: ['GET'], headers: { 'DNT' => '1' })
              end

              it 'sends custom headers' do
                expect(result.request_headers['DNT']).to eq '1'
              end
            end

            it 'returns results' do
              expect(subject.results).to eq(
                error: [],
                failure: [],
                success: [
                  result
                ],
                blocked: []
              )
            end

            it 'succeeds' do
              expect(result.success?).to be true
              expect(result.error?).to be false
              expect(result.failure?).to be false
              expect(result.uri).to eq URI(url)
              expect(subject).to have_received(:called!).with(:result, result)
              expect(subject).to have_received(:called!).with(:success, result)
            end
          end

          context 'a 404', vcr: { cassette_name: '404', allow_playback_repeats: true } do
            it 'fails' do
              expect(result.success?).to be false
              expect(result.error?).to be false
              expect(result.failure?).to be true
              expect(result.uri).to eq URI(url)
              expect(result.response.code.to_i).to eq 404
              expect(subject).to have_received(:called!).with(:failure, result)
            end

            context 'with 0 retries' do
              subject do
                described_class.new(methods: ['GET'], retries: 0)
              end

              it 'fails' do
                expect(result.success?).to be false
                expect(result.error?).to be false
                expect(result.failure?).to be true
                expect(result.uri).to eq URI(url)
                expect(result.response.code.to_i).to eq 404
                expect(subject).to have_received(:called!).with(:failure, result).once
                expect(subject).not_to have_received(:called!).with(:retry, anything)
              end
            end

            context 'with 1 retry' do
              subject do
                described_class.new(methods: ['GET'], retries: 1, retry_status_codes: nil)
              end

              it 'fails' do
                expect(result.success?).to be false
                expect(result.error?).to be false
                expect(result.failure?).to be true
                expect(result.uri).to eq URI(url)
                expect(result.response.code.to_i).to eq 404
                expect(subject).to have_received(:called!).with(:failure, result).once
                expect(subject).to have_received(:called!).with(:retry, anything).once
              end
            end

            context 'with 2 retries' do
              subject do
                described_class.new(methods: ['GET'], retries: 2, retry_status_codes: nil)
              end

              it 'fails' do
                expect(result.success?).to be false
                expect(result.error?).to be false
                expect(result.failure?).to be true
                expect(result.uri).to eq URI(url)
                expect(result.response.code.to_i).to eq 404
                expect(subject).to have_received(:called!).with(:failure, result).once
                expect(subject).to have_received(:called!).with(:retry, anything).twice
              end
            end
          end

          context 'a redirect on HEAD followed by a 403', vcr: { cassette_name: '301+403' } do
            it 'calls redirect callback' do
              expect(result.success?).to be false
              expect(result.failure?).to be false
              expect(result.blocked?).to be true
              expect(subject).to have_received(:called!).with(:redirect, anything)
              expect(subject).to have_received(:called!).with(:blocked, result).once
            end

            it 'reports its original and result urls' do
              expect(result.uri.to_s).to eq url
              expect(result.result_uri.to_s).not_to eq url
              expect(result.result_uri.to_s).to eq 'https://www.dblock.org/'
            end
          end

          context 'a redirect on HEAD followed by a 200', vcr: { cassette_name: '301+200' } do
            it 'calls redirect callback' do
              expect(result.success?).to be true
              expect(result.failure?).to be false
              expect(result.redirect?).to be false
              expect(subject).to have_received(:called!).with(:redirect, anything)
              expect(subject).to have_received(:called!).with(:success, result)
              expect(subject).not_to have_received(:called!).with(:failure, anything)
            end
          end

          context 'a redirect loop', vcr: { cassette_name: '301+301' } do
            it 'calls redirect callback' do
              expect(result.success?).to be false
              expect(result.failure?).to be false
              expect(result.error?).to be true
              expect(result.error).to be_a LinkChecker::Errors::RedirectLoopError
              expect(result.redirect?).to be false
              expect(subject).to have_received(:called!).with(:redirect, anything).once
              expect(subject).to have_received(:called!).with(:error, result)
              expect(subject).not_to have_received(:called!).with(:failure, result)
              expect(subject).not_to have_received(:called!).with(:success, result)
            end
          end

          context 'a retry on 429', vcr: {
            cassette_name: '429+200',
            match_requests_on: [lambda { |_request, recorded_request|
              @matched ||= []
              if @matched.size + 1 === recorded_request.headers['Index'].first
                @matched << recorded_request
                true
              else
                false
              end
            }]
          } do
            subject do
              described_class.new(methods: ['GET'], retries: 1, rate_limit_retries: 0)
            end

            it 'calls a retry callback' do
              expect(result.success?).to be true
              expect(result.failure?).to be false
              expect(result.redirect?).to be false
              expect(subject).to have_received(:called!).with(:retry, anything)
              expect(subject).to have_received(:called!).with(:success, result)
              expect(subject).not_to have_received(:called!).with(:failure, anything)
              expect(subject).not_to have_received(:called!).with(:error, anything)
            end
          end

          context 'a failed retry on a redirect', vcr: { cassette_name: '308+429', allow_playback_repeats: true } do
            subject do
              described_class.new(methods: %w[HEAD], retries: 2, rate_limit_retries: 0)
            end

            it 'calls redirect callback' do
              expect(result.success?).to be false
              expect(result.blocked?).to be true
              expect(result.error?).to be false
              expect(result.error).not_to be_a LinkChecker::Errors::RedirectLoopError
            end
          end

          context 'an invalid URI' do
            let(:url) { '\/invalid-url' }

            it 'fails' do
              expect(result.success?).to be false
              expect(result.failure?).to be false
              expect(result.error?).to be true
              expect(result.uri).to eq url
              expect(subject).to have_received(:called!).with(:result, result)
              expect(subject).to have_received(:called!).with(:error, result)
              expect(subject).not_to have_received(:called!).with(:failure)
              expect(subject).not_to have_received(:called!).with(:success)
            end
          end
        end

        context 'HEAD,GET' do
          subject do
            described_class.new(methods: %w[HEAD GET])
          end

          context 'a valid URI that fails on HEAD and succeeds on GET', vcr: { cassette_name: '404+200' } do
            it 'succeeds' do
              expect(result.success?).to be true
              expect(result.error?).to be false
              expect(result.failure?).to be false
              expect(result.uri).to eq URI(url)
              expect(subject).to have_received(:called!).with(:success, result)
              expect(subject).not_to have_received(:called!).with(:failure, result)
            end
          end

          context 'a valid URI that fails both on HEAD and GET', vcr: { cassette_name: '404+404' } do
            it 'fails' do
              expect(result.success?).to be false
              expect(result.error?).to be false
              expect(result.failure?).to be true
              expect(result.uri).to eq URI(url)
              expect(result.response.code.to_i).to eq 404
              expect(subject).to have_received(:called!).with(:failure, result).once
            end
          end

          context 'a retry on 429', vcr: {
            cassette_name: '429+429+200',
            match_requests_on: [lambda { |request, recorded_request|
              @matched ||= []
              if recorded_request.method == request.method && @matched.size + 1 === recorded_request.headers['Index'].first
                @matched << recorded_request
                true
              else
                false
              end
            }]
          } do
            subject do
              described_class.new(methods: %w[HEAD GET], retries: 1, rate_limit_retries: 0)
            end

            it 'executes HEAD twice, then falls back to GET' do
              expect(result.success?).to be true
            end
          end

          context 'a redirect on HEAD followed by a 400 error succeeds on GET',
                  vcr: { cassette_name: '301+400+301+200' } do
            it 'calls redirect callback' do
              expect(result.success?).to be true
              expect(result.failure?).to be false
              expect(result.redirect?).to be false
              expect(subject).to have_received(:called!).with(:redirect, anything).twice
              expect(subject).to have_received(:called!).with(:success, result).once
              expect(subject).not_to have_received(:called!).with(:failure, anything)
            end
          end
        end
      end
    end
  end
end
