# frozen_string_literal: true
require 'spec_helper'

describe LinkChecker::Config do
  describe '#configure' do
    context 'methods' do
      before do
        LinkChecker.configure do |config|
          config.methods = %w[GET]
        end
      end

      it 'sets methods' do
        expect(LinkChecker.config.methods).to eq %w[GET]
      end
    end

    context 'retries' do
      it 'requires a positive integer' do
        expect { LinkChecker.config.retries = -1 }.to raise_error ArgumentError, 'Invalid number of retries: -1'
      end

      context 'blocked_status_codes' do
        it 'accepts non-standard status codes' do
          LinkChecker.config.blocked_status_codes = [403, 999]
          expect(LinkChecker.config.blocked_status_codes).to eq [403, 999]
        end

        it 'treats nil as no blocked status codes' do
          LinkChecker.config.blocked_status_codes = nil
          expect(LinkChecker.config.blocked_status_codes).to eq []
        end

        it 'rejects status codes out of range' do
          message = 'Invalid blocked status codes: [1000]'
          expect { LinkChecker.config.blocked_status_codes = [1000] }.to raise_error ArgumentError, message
        end

        it 'rejects values that are not arrays' do
          message = 'Invalid blocked status codes: 403'
          expect { LinkChecker.config.blocked_status_codes = '403' }.to raise_error ArgumentError, message
        end
      end

      context 'detect_challenges' do
        it 'requires a boolean' do
          message = 'Invalid detect_challenges: yes'
          expect { LinkChecker.config.detect_challenges = 'yes' }.to raise_error ArgumentError, message
        end
      end

      context 'max_concurrency_per_host' do
        it 'requires a positive integer' do
          message = 'Invalid concurrency limit per host: 0'
          expect { LinkChecker.config.max_concurrency_per_host = 0 }.to raise_error ArgumentError, message
        end
      end

      context 'min_host_interval' do
        it 'rejects negative intervals' do
          message = 'Invalid min_host_interval: -1'
          expect { LinkChecker.config.min_host_interval = -1 }.to raise_error ArgumentError, message
        end
      end

      context 'max_redirects' do
        it 'rejects negative limits' do
          expect { LinkChecker.config.max_redirects = -1 }.to raise_error ArgumentError, 'Invalid redirect limit: -1'
        end
      end
    end
  end

  describe 'defaults' do
    it 'sets methods' do
      expect(LinkChecker.config.methods).to eq %w[HEAD GET]
    end
    it 'sets user agent' do
        expect(LinkChecker.config.user_agent).to eq "Ruby Link Checker/#{LinkChecker::VERSION}"
    end
    it 'does not set logger' do
        expect(LinkChecker.config.logger).to be nil
    end
    it 'sets retries' do
      expect(LinkChecker.config.retries).to eq 0
    end
    it 'blocks status codes that bot protection commonly returns' do
      expect(LinkChecker.config.blocked_status_codes).to eq [401, 403, 429, 999]
    end
    it 'does not limit concurrency per host' do
      expect(LinkChecker.config.max_concurrency_per_host).to be_nil
      expect(LinkChecker.config.min_host_interval).to eq 0
    end
    it 'detects challenges' do
      expect(LinkChecker.config.detect_challenges).to be true
    end
  end  
end