# frozen_string_literal: true

module LinkChecker
  module Errors
    class InvalidHttpMethodError < BaseError
      attr_accessor :method

      def initialize(method)
        @method = method
        super "Unsupported or invalid HTTP method: #{method}."
      end
    end
  end
end
