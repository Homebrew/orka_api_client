# frozen_string_literal: true

require "faraday"
require "faraday/multipart"
require_relative "auth_middleware"

module OrkaAPI
  # @api private
  class Connection < ::Faraday::Connection
    # @param [String] base_url
    # @param [String] token
    # @param [String] license_key
    def initialize(base_url, token: nil, license_key: nil)
      super(
        url:     base_url,
        headers: {
          "User-Agent" => "HomebrewOrkaClient/#{Client::VERSION}",
        },
        request: {
          timeout: 120,
        }
      ) do |f|
        f.request :orka_auth, token: token, license_key: license_key
        f.request :json
        f.request :multipart
        f.response :json
        f.response :raise_error # TODO: wrap this ourselves
      end
    end

    alias inspect to_s
  end
end
