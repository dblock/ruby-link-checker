# frozen_string_literal: true

module LinkChecker
  module Errors
    class RedirectLimitError < BaseError
      attr_reader :limit, :urls

      def initialize(limit, urls)
        @limit = limit
        @urls = urls
        super("Redirect limit of #{limit} exceeded: #{urls.join(' -> ')}.")
      end
    end
  end
end
