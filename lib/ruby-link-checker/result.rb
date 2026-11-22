require 'timeout'
require 'socket'

module LinkChecker
  class Result
    attr_accessor :uri, :result_uri, :method, :options, :checker
    attr_writer :cached, :blocked, :redirects

    def initialize(current_uri, method, original_uri, options = {})
      @uri = original_uri
      @result_uri = current_uri
      @method = method
      @options = options
    end

    def success?
      false
    end

    def cached?
      !!@cached
    end

    def failure?
      false
    end

    # A final HTTP result whose status code or bot challenge matched the checker's blocked settings.
    def blocked?
      !!@blocked
    end

    def error?
      false
    end

    # Seconds the server asked to wait with Retry-After (delta-seconds or an HTTP date), or 0.
    def retry_after_delay
      value = Array(response_headers['Retry-After'] || response_headers['retry-after']).first.to_s.strip
      return value.to_i if /\A\d+\z/.match?(value)

      [Time.httpdate(value) - Time.now, 0].max
    rescue ArgumentError
      0
    end

    # Known bot challenges, detected from response headers: the name of the challenge, the header, and its value.
    CHALLENGES = [
      # https://developers.cloudflare.com/cloudflare-challenges/challenge-types/challenge-pages/detect-response/
      %w[Cloudflare cf-mitigated challenge]
    ].freeze

    # The name of the bot challenge that the response carries, such as "Cloudflare", or nil.
    def challenge
      CHALLENGES.find do |_name, header, value|
        Array(response_headers[header]).join(',').split(',').map(&:strip).include?(value)
      end&.first
    end

    # Whether the response carries a known bot challenge.
    def challenge?
      !challenge.nil?
    end

    def redirect?
      false
    end

    def redirect_to
      nil
    end

    # The redirect hops that led to this result, oldest first.
    def redirects
      @redirects || []
    end

    # Whether any redirect hop that led to this result was permanent (301 or 308).
    def permanent_redirect?
      redirects.any?(&:permanent?)
    end

    def request_headers
      {}
    end

    def response_headers
      {}
    end

    def error_type
      nil
    end

    def code
      nil
    end

    def error
      nil
    end

    # :success, :failure, :blocked, or :error for a final result, or :redirect for a redirect hop.
    def outcome
      if success? then :success
      elsif blocked? then :blocked
      elsif error? then :error
      elsif redirect? then :redirect
      else :failure
      end
    end

    # A stable, human-readable explanation of the outcome, such as "HTTP 404" or "Cloudflare challenge (HTTP 403)".
    def reason
      name = challenge unless success?
      name ? "#{name} challenge (HTTP #{code})" : "HTTP #{code}"
    end

    # A serializable summary of the result.
    def to_h
      {
        url: uri.to_s,
        result_url: result_uri.to_s,
        method: method,
        code: code.is_a?(Integer) ? code : nil,
        outcome: outcome,
        reason: reason,
        redirects: redirects.map { |hop| { url: hop.uri.to_s, code: hop.code, to: hop.to.to_s } },
        permanent_redirect: permanent_redirect?,
        blocked: blocked?,
        challenge: challenge,
        cached: cached?,
        error: error&.message,
        error_type: error_type,
        options: options
      }
    end

    def to_s
      status_s = if success?
                   'OK'
                 elsif blocked?
                   'BLOCKED'
                 elsif failure?
                   'FAIL'
                 elsif redirect?
                   'REDIRECT'
                 else
                   'ERROR'
                 end
      "#{method} #{uri}#{result_uri == uri ? nil : ' (' + result_uri.to_s + ')'} : #{status_s} (#{code})"
    end
  end

  class ResultError < Result
    attr_accessor :error

    def initialize(uri, method, original_uri, error, options = {})
      @error = error
      super uri, method, original_uri, options
    end

    def error?
      true
    end

    def code
      error.class.name
    end

    def reason
      case error
      when LinkChecker::Errors::RedirectLoopError then 'Redirect loop'
      when LinkChecker::Errors::RedirectLimitError then 'Too many redirects'
      when URI::InvalidURIError then 'Invalid URL'
      else
        case error_type
        when :timeout then 'Timeout'
        when :connection then 'Connection error'
        else "Error (#{error.class.name})"
        end
      end
    end

    def error_type
      return :timeout if error.is_a?(Timeout::Error)
      return :timeout if defined?(::Async::TimeoutError) && error.is_a?(::Async::TimeoutError)
      return error.error_type if error.is_a?(LinkChecker::Errors::ConnectionError)
      return :connection if [IOError, SystemCallError, SocketError].any? { |klass| error.is_a?(klass) }

      :other
    end
  end
end
