# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Typhoeus::Hydra::Checker do
  module TyphoeusTestLinkChecker
    class Task < LinkChecker::Typhoeus::Hydra::Task; end

    class LinkChecker < LinkChecker::Typhoeus::Hydra::Checker
      def check(url, options = {})
        super url, options
        @hydra.run
      end
    end
  end
  before :all do
    VCR.configure do |config|
      config.hook_into :webmock
    end
  end

  describe TyphoeusTestLinkChecker::LinkChecker do
    it_behaves_like 'a link checker'

    describe '.config' do
      it 'returns the Config module' do
        expect(LinkChecker::Typhoeus::Hydra.config).to eq LinkChecker::Typhoeus::Hydra::Config
      end
    end

    context 'with timeout options', vcr: { cassette_name: '200' } do
      before do
        LinkChecker::Typhoeus::Hydra.configure do |config|
          config.timeout = 5
          config.connecttimeout = 10
        end
        expect(Typhoeus::Request).to receive(:new).with(
          URI(url),
          hash_including(timeout: 5, connecttimeout: 10)
        ).and_call_original
      end

      include_context 'with url'

      it 'creates requests with a default timeout' do
        expect(result.success?).to be true
      end
    end

    context 'timeout', vcr: { cassette_name: '200' } do
      before do
        allow_any_instance_of(Typhoeus::Response).to receive(:timed_out?).and_return(true)
      end

      include_context 'with url'

      it 'times out' do
        expect(result.success?).to be false
        expect(result.error?).to be true
        expect(result.to_s).to eq 'GET https://www.example.org : ERROR (Timeout::Error)'
      end

      context 'with metadata' do
        let(:options) { { foo: :bar } }

        it 'times out' do
          expect(result.error?).to be true
          expect(result.options).to eq(foo: :bar)
        end
      end
    end
  end

  describe LinkChecker::Typhoeus::Hydra::Result do
    describe '#code' do
      it 'returns -1 when the response raises' do
        request = instance_double(Typhoeus::Request)
        response = instance_double(Typhoeus::Response)
        allow(response).to receive(:code).and_raise(StandardError)
        result = described_class.new(URI('https://www.example.org'), 'GET', nil, request, response, {})
        expect(result.code).to eq(-1)
      end
    end
  end

  describe '#run' do
    it 'delegates to the hydra' do
      checker = described_class.new
      expect(checker.instance_variable_get(:@hydra)).to receive(:run)
      checker.run
    end
  end

  describe 'delayed retries' do
    let(:checker) { described_class.new(methods: ['GET'], retries: 1, retry_after: 0.005) }

    around do |example|
      VCR.turned_off { example.run }
    end

    it 'processes unrelated requests before waiting for a retry' do
      completed = []
      stub_request(:get, 'https://www.example.org/retry').to_return({ status: 503 }, { status: 200 })
      stub_request(:get, 'https://www.example.org/other').to_return(status: 200)
      checker.on(:success) { |result| completed << result.uri.path }
      checker.check('https://www.example.org/retry')
      checker.check('https://www.example.org/other')
      checker.run
      expect(completed).to eq(['/other', '/retry'])
    end
  end

  describe 'transport failures' do
    let(:checker) { described_class.new(methods: ['GET']) }

    around do |example|
      VCR.turned_off do
        WebMock.disable!
        Typhoeus::Config.block_connection = true
        example.run
      ensure
        Typhoeus::Config.block_connection = false
        WebMock.enable!
      end
    end

    after do
      Typhoeus::Expectation.clear
    end

    it 'reports connection errors separately from HTTP failures' do
      response = Typhoeus::Response.new(code: 0, return_code: :couldnt_connect)
      Typhoeus.stub(nil).and_return(response)
      checker.check('https://www.example.org/')
      checker.run
      expect(checker.results[:failure]).to be_empty
      expect(checker.results[:error].first.error_type).to eq(:connection)
    end
  end

  describe 'in-flight deduplication' do
    let(:checker) { described_class.new(methods: ['GET'], deduplicate: true) }
    let(:url) { 'https://www.example.org/' }

    around do |example|
      VCR.turned_off { example.run }
    end

    it 'fans out events to duplicates queued before completion' do
      metadata = []
      stub_request(:any, url).to_return(status: 200)
      checker.on(:result) { |result| metadata << result.options }
      checker.check(url, location: 'one.html')
      checker.check(url, location: 'two.html')
      checker.run
      expect(a_request(:any, url)).to have_been_made.once
      expect(metadata).to eq([{ location: 'one.html' }, { location: 'two.html' }])
    end

    it 'replays events when a subscriber joins during a result callback' do
      stub_request(:any, url).to_return(status: 200)
      checker.on(:result) { |result| checker.check(url, location: 'two.html') if result.options[:location] == 'one.html' }
      checker.check(url, location: 'one.html')
      checker.run
      expect(checker.results[:success].map(&:options)).to eq([{ location: 'one.html' }, { location: 'two.html' }])
      expect(a_request(:any, url)).to have_been_made.once
    end

    it 'does not memoize a response if settings changed while queued' do
      stub_request(:any, url).to_return(status: 200)
      checker.check(url)
      checker.headers = { 'Accept' => 'text/html' }
      checker.run
      checker.headers = {}
      checker.check(url)
      checker.run
      expect(a_request(:any, url)).to have_been_made.twice
    end
  end
end
