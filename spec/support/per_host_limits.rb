# frozen_string_literal: true

shared_examples 'a link checker with per-host limits' do |concurrent: true|
  context 'with per-host limits', :aggregate_failures do
    let(:server) { HostServer.new }
    let(:urls) { Array.new(6) { |index| server.url("/page/#{index}") } }

    around do |example|
      VCR.turned_off do
        WebMock.allow_net_connect!
        example.run
      ensure
        WebMock.disable_net_connect!
      end
    end

    after do
      server.stop
    end

    def check_all(checker)
      urls.each { |url| checker.check(url) }
      checker.run if checker.respond_to?(:run)
      checker
    end

    if concurrent
      it 'checks a host concurrently without a limit' do
        checker = check_all(described_class.new(methods: ['GET']))
        expect(checker.results[:success].size).to eq 6
        expect(server.max_active).to be > 2
      end

      it 'bounds requests in flight to the same host' do
        checker = check_all(described_class.new(methods: ['GET'], max_concurrency_per_host: 2))
        expect(checker.results[:success].size).to eq 6
        expect(server.max_active).to be <= 2
      end
    end

    it 'follows redirects and retries to the same host within the limits' do
      stub_request(:get, 'https://www.example.org/start').to_return(status: 302, headers: { 'Location' => '/next' })
      stub_request(:get, 'https://www.example.org/next').to_return({ status: 503 }, { status: 200 })
      checker = described_class.new(methods: ['GET'], retries: 1, max_concurrency_per_host: 1, min_host_interval: 0.01)
      checker.check('https://www.example.org/start')
      checker.run if checker.respond_to?(:run)
      expect(checker.results[:success].map { |result| result.result_uri.to_s }).to eq ['https://www.example.org/next']
    end

    it 'spaces out requests to the same host' do
      checker = check_all(described_class.new(methods: ['GET'], min_host_interval: 0.05))
      expect(checker.results[:success].size).to eq 6
      expect(server.starts.size).to eq 6
      # Five intervals of 0.05s separate six requests; allow for network jitter on individual requests.
      expect(server.starts.max - server.starts.min).to be >= 0.2
    end
  end
end
