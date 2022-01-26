# frozen_string_literal: true

module OrkaAPI
  module Models
    # The requirements enforced for passwords when creating a user account.
    class PasswordRequirements
      # @return [Integer] The minimum length of a password.
      attr_reader :length

      # @api private
      # @param [Hash] hash
      def initialize(hash)
        @length = hash["password_length"]
      end
    end
  end
end
