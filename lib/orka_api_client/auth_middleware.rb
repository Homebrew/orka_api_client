# frozen_string_literal: true

module OrkaAPI
  # @api private
  class AuthMiddleware < ::Faraday::Middleware
    def initialize(app, token: nil, license_key: nil)
      super(app)

      @token = token
      @license_key = license_key
    end

    def on_request(env)
      auth_type = env.request.context&.dig(:orka_auth_type)

      Array(auth_type).each do |type|
        case type
        when :license
          header = "orka-licensekey"
          value = @license_key
        when :token
          header = "Authorization"
          value = "Bearer #{@token}"
        when nil, :none
          next
        else
          raise AuthConfigurationError, "Invalid Orka auth type."
        end

        raise AuthConfigurationError, "Missing #{type} credential." if value.nil?

        next if env.request_headers[header]

        env.request_headers[header] = value
      end
    end
  end
end

Faraday::Request.register_middleware(orka_auth: OrkaAPI::AuthMiddleware)
