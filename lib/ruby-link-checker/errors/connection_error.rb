# frozen_string_literal: true

module LinkChecker
  module Errors
    class ConnectionError < BaseError
      TRANSIENT_CODES = %i[
        couldnt_resolve_proxy couldnt_resolve_host couldnt_connect
        partial_file got_nothing send_error recv_error http2 http2_stream
      ].freeze

      attr_reader :return_code

      def initialize(return_code, message)
        @return_code = return_code
        super(message)
      end

      def error_type
        TRANSIENT_CODES.include?(return_code) ? :connection : :other
      end
    end
  end
end
