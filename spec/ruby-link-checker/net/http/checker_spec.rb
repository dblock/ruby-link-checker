# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Net::HTTP::Checker do
  before :all do
    VCR.configure do |config|
      config.hook_into :webmock
    end
  end

  it_behaves_like 'a link checker'
end
