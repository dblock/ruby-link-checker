# frozen_string_literal: true

module LinkChecker
  module Errors
    class RedirectLoopError < BaseError
      def initialize(urls)
        @urls = urls
        super "Redirect loop: #{urls.join(' -> ')}."
      end

      def url
        @urls.last
      end
    end
  end
end
