# frozen_string_literal: true

require 'spec_helper'
require 'async'
require 'async/http'

describe LinkChecker::Async::HTTP::Checker do
  module AsyncTestLinkChecker
    class Task < LinkChecker::Async::HTTP::Task; end

    class LinkChecker < LinkChecker::Async::HTTP::Checker
      def check(url, options = {})
        super
        run
      end
    end
  end

  before :all do
    VCR.configure do |config|
      config.hook_into :webmock
      # async-http's WebMock adapter replays responses through a real HTTP/1
      # parser, which rejects a Transfer-Encoding header alongside a
      # Content-Length or an empty body, unlike the other checkers' adapters.
      config.before_playback do |interaction|
        interaction.response.headers.delete('Transfer-Encoding')
      end
    end
  end

  after do
    LinkChecker::Async::HTTP::Config.reset
  end

  describe AsyncTestLinkChecker::LinkChecker do
    it_behaves_like 'a link checker'

    describe '.config' do
      it 'returns the Config module' do
        expect(LinkChecker::Async::HTTP.config).to eq LinkChecker::Async::HTTP::Config
      end
    end

    context 'with timeout options', vcr: { cassette_name: '200' } do
      before do
        LinkChecker::Async::HTTP.configure do |config|
          config.read_timeout = 5
          config.open_timeout = 10
        end
        expect(Async::HTTP::Endpoint).to receive(:parse).with(
          URI(url).to_s,
          hash_including(timeout: 10)
        ).and_call_original
      end

      include_context 'with url'

      it 'creates requests with a default timeout' do
        expect(result.success?).to be true
      end
    end

    context 'with a protocol option', vcr: { cassette_name: '200' } do
      before do
        LinkChecker::Async::HTTP.configure do |config|
          config.protocol = protocol
        end
        expect(Async::HTTP::Endpoint).to receive(:parse).with(
          URI(url).to_s,
          hash_including(protocol: expected_protocol)
        ).and_call_original
      end

      include_context 'with url'

      context 'http1' do
        let(:protocol) { :http1 }
        let(:expected_protocol) { Async::HTTP::Protocol::HTTP1 }

        it 'creates requests using HTTP/1' do
          expect(result.success?).to be true
        end
      end

      context 'http2' do
        let(:protocol) { :http2 }
        let(:expected_protocol) { Async::HTTP::Protocol::HTTP2 }

        it 'creates requests using HTTP/2' do
          expect(result.success?).to be true
        end
      end
    end

    context 'with an unsupported protocol option' do
      before do
        LinkChecker::Async::HTTP.configure do |config|
          config.protocol = :http3
        end
      end

      include_context 'with url'

      it 'raises an ArgumentError' do
        expect(result.error?).to be true
        expect(result.error.message).to eq('Unsupported protocol: :http3, expected :http1 or :http2')
      end
    end

    context 'timeout' do
      before do
        stub_request(:get, 'https://www.example.org/').to_timeout
      end

      include_context 'with url'

      around do |example|
        VCR.turned_off { example.run }
      end

      it 'times out' do
        expect(result.success?).to be false
        expect(result.error?).to be true
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

  describe LinkChecker::Async::HTTP::Result do
    describe '#code' do
      it 'returns -1 when there is no response' do
        request = instance_double(Protocol::HTTP::Request)
        result = described_class.new(URI('https://www.example.org'), 'GET', nil, request, nil, {})
        expect(result.code).to eq(-1)
      end
    end
  end
end
