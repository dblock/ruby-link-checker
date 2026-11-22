# frozen_string_literal: true
require 'spec_helper'

describe LinkChecker::Checker do
  describe 'request identity' do
    let(:checker) { LinkChecker::Net::HTTP::Checker.new }

    it 'does not change when host headers are empty' do
      key = checker.send(:request_key, 'https://www.example.org/')
      checker.host_headers = { 'www.example.org' => {} }
      expect(checker.send(:request_key, 'https://www.example.org/')).not_to eq key
      checker.host_headers = {}
      expect(checker.send(:request_key, 'https://www.example.org/')).to eq key
    end
  end

  describe 'per-host slots' do
    let(:checker) { LinkChecker::Net::HTTP::Checker.new(min_host_interval: 10) }

    it 'spaces reservations for the same host' do
      expect(checker._reserve_host_slot('www.example.org')).to eq 0
      expect(checker._reserve_host_slot('www.example.org')).to be > 9
    end

    it 'keeps hosts independent' do
      checker._reserve_host_slot('www.example.org')
      expect(checker._reserve_host_slot('www.example.com')).to eq 0
    end

    it 'does not delay URIs without a host' do
      expect(checker._host_key('\\/invalid-url')).to be_nil
      expect(checker._reserve_host_slot(nil)).to eq 0
    end

    it 'normalizes host case' do
      expect(checker._host_key('https://WWW.Example.org/path')).to eq 'www.example.org'
    end
  end

  describe LinkChecker::Cache do
    let(:directory) { Dir.mktmpdir('link-checker-spec-') }
    let(:file) { File.join(directory, 'cache.json') }
    let(:cache) { described_class.new({ file: file, ttl: 60 }, logger: LinkChecker::Logger.default) }
    let(:result) do
      LinkChecker::Net::HTTP::Result.new(
        URI('https://www.example.org/final'), 'GET', URI('https://www.example.org/'),
        {}, Net::HTTPOK.new('1.1', '200', 'OK'), { location: 'private.html' }
      )
    end

    after do
      FileUtils.remove_entry(directory)
    end

    it 'expires successful entries using the configured TTL' do
      cache.store('key', result)
      allow(Time).to receive(:now).and_return(Time.now + 61)
      expect(cache.fetch('key', 'https://www.example.org/')).to be_nil
    end

    it 'retains the final URL and status without persisting metadata or headers' do
      cache.store('key', result)
      restored = cache.fetch('key', 'https://www.example.org/')
      expect(restored.result_uri.to_s).to eq('https://www.example.org/final')
      expect(restored.code).to eq(200)
      data = JSON.parse(File.read(file)).fetch('entries').fetch('key')
      expect(data.keys).to contain_exactly('checked_at', 'method', 'code', 'result_uri', 'redirects')
    end

    it 'retains redirect hops' do
      result.redirects = [LinkChecker::Redirect.new(uri: URI('https://www.example.org/'), code: 301, to: URI('https://www.example.org/final'))]
      cache.store('key', result)
      restored = cache.fetch('key', 'https://www.example.org/')
      expect(restored.redirects.map(&:code)).to eq [301]
      expect(restored.redirects.first.to).to eq URI('https://www.example.org/final')
      expect(restored.permanent_redirect?).to be true
    end

    it 'does not store credentials in redirect hops' do
      hop = LinkChecker::Redirect.new(uri: URI('https://user:password@www.example.org/'), code: 302, to: URI('https://www.example.org/final'))
      result.redirects = [hop]
      cache.store('key', result)
      expect(File).not_to exist(file)
    end

    it 'ignores entries from the previous cache version' do
      entry = { 'checked_at' => Time.now.to_f, 'method' => 'GET', 'code' => 200, 'result_uri' => 'https://www.example.org/' }
      File.write(file, JSON.generate('version' => 1, 'entries' => { 'key' => entry }))
      expect(cache.fetch('key', 'https://www.example.org/')).to be_nil
    end

    it 'ignores entries with malformed redirect hops' do
      cache.store('key', result)
      data = JSON.parse(File.read(file))
      data['entries']['key']['redirects'] = [['https://user:password@www.example.org/', 301, 'https://www.example.org/']]
      File.write(file, JSON.generate(data))
      expect(cache.fetch('key', 'https://www.example.org/')).to be_nil
    end

    it 'merges writes from separate cache instances' do
      other_cache = described_class.new({ file: file, ttl: 60 }, logger: LinkChecker::Logger.default)
      cache.store('one', result)
      other_cache.store('two', result)
      expect(cache.fetch('one', 'https://www.example.org/')).not_to be_nil
      expect(cache.fetch('two', 'https://www.example.org/')).not_to be_nil
    end

    it 'recovers from corrupted cache files' do
      File.write(file, 'invalid JSON')
      expect(cache.fetch('key', 'https://www.example.org/')).to be_nil
      cache.store('key', result)
      expect(cache.fetch('key', 'https://www.example.org/').code).to eq(200)
    end

    it 'ignores malformed cache entries' do
      File.write(file, JSON.generate('version' => LinkChecker::Cache::VERSION, 'entries' => { 'key' => true }))
      expect(cache.fetch('key', 'https://www.example.org/')).to be_nil
    end

    it 'does not store credentials in redirect URLs' do
      result.result_uri = URI('https://user:password@www.example.org/')
      cache.store('key', result)
      expect(File).not_to exist(file)
    end

    it 'requires an explicit file and TTL' do
      expect { described_class.new({}, logger: LinkChecker::Logger.default) }.to raise_error ArgumentError
      expect { described_class.new({ file: file }, logger: LinkChecker::Logger.default) }.to raise_error ArgumentError
    end

    it 'does not turn a cache write failure into a failed link' do
      allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES)
      expect { cache.store('key', result) }.not_to raise_error
    end
  end

  context 'config' do
    it 'requires at least one method' do
      expect { described_class.new(methods: []) }.to raise_error ArgumentError, 'Missing methods.'
    end

    it 'rejects an invalid redirect limit' do
      expect { described_class.new(max_redirects: -1) }.to raise_error ArgumentError, 'Invalid redirect limit: -1'
    end

    it 'validates retry delays and backoff' do
      expect { described_class.new(retry_after: -1) }.to raise_error ArgumentError
      expect { described_class.new(retry_backoff: 0.5) }.to raise_error ArgumentError
      expect { described_class.new(retry_jitter: 2) }.to raise_error ArgumentError
      expect { described_class.new(max_retry_delay: Float::INFINITY) }.to raise_error ArgumentError
    end

    it 'rejects invalid retry status codes' do
      expect { described_class.new(retry_status_codes: ['503']) }.to raise_error ArgumentError
    end

    it 'allows per-instance disabling of global Retry-After handling' do
      LinkChecker.config.respect_retry_after = true
      expect(described_class.new(respect_retry_after: false).respect_retry_after).to be false
    end
  end
end