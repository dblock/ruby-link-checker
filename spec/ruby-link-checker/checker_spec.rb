# frozen_string_literal: true
require 'spec_helper'

describe LinkChecker::Checker do
    context 'config' do
    it 'requires at least one method' do
      expect { LinkChecker::Checker.new(methods: []) }.to raise_error ArgumentError, 'Missing methods.'
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