# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module RubyGemRelease
  module Workflow
    class RubyGemsCredentials
      def initialize(owner:)
        raise ArgumentError, 'RubyGems owner must be a positive numeric account ID' unless /\A[1-9]\d*\z/.match?(owner.to_s)

        @owner = owner.to_s
      end

      def configure!
        token = oidc_token
        mask(token)
        key = exchange_token(token)
        mask(key)
        File.open(ENV.fetch('GITHUB_ENV'), 'a') do |file|
          %w[RUBYGEMS_API_KEY BUNDLE_GEM__PUSH_KEY GEM_HOST_API_KEY].each { |name| file.puts "#{name}=#{key}" }
        end
      end

      private

      def oidc_token
        uri = URI(ENV.fetch('ACTIONS_ID_TOKEN_REQUEST_URL'))
        raise ArgumentError, 'OIDC request URL must use HTTPS' unless uri.is_a?(URI::HTTPS)

        query = URI.decode_www_form(uri.query || '').reject { |name, _value| name == 'audience' } # rubocop:disable Style/HashExcept -- Query pairs may contain duplicate keys.
        uri.query = URI.encode_www_form(query + [['audience', 'rubygems.org']])
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{ENV.fetch('ACTIONS_ID_TOKEN_REQUEST_TOKEN')}"
        credential(response(uri, request), 'value')
      end

      def exchange_token(token)
        uri = URI('https://rubygems.org/api/v1/oidc/trusted_publisher/exchange_token')
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['Accept'] = 'application/json'
        request.body = JSON.generate(jwt: token, owner: @owner)
        credential(response(uri, request), 'rubygems_api_key')
      end

      def response(uri, request)
        result = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30, max_retries: 0) do |http|
          http.request(request)
        end
        raise "Credential request failed (HTTP #{result.code}); verify owner ID and pending trusted publisher" unless result.is_a?(Net::HTTPSuccess)

        JSON.parse(result.body)
      rescue JSON::ParserError
        raise 'Credential response was not valid JSON'
      end

      def credential(body, name)
        value = body[name] if body.is_a?(Hash)
        raise 'Credential response did not contain a valid token' unless value.is_a?(String) && !value.empty? && !value.match?(/[\r\n]/)

        value
      end

      def mask(value)
        puts "::add-mask::#{value.gsub('%', '%25')}"
      end
    end
  end
end
