# frozen_string_literal: true
require 'spec_helper'

describe LinkChecker::Config do
  describe '#configure' do
    before do
      LinkChecker.configure do |config|
        config.methods = %w[GET]
      end
    end

    it 'sets methods' do
      expect(LinkChecker.config.methods).to eq %w[GET]
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
  end  
end