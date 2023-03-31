# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Typhoeus::Hydra::Checker do
  module TestLinkChecker
    class Task < LinkChecker::Typhoeus::Hydra::Task; end

    class LinkChecker < LinkChecker::Typhoeus::Hydra::Checker
      def check(url)
        super url
        @hydra.run
      end
    end
  end
  before :all do
    VCR.configure do |config|
      config.hook_into :typhoeus
    end
  end

  describe TestLinkChecker::LinkChecker do
    it_behaves_like 'a link checker'
  end
end
