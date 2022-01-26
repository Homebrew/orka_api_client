# frozen_string_literal: true

require_relative "attr_predicate"
require_relative "user"

module OrkaAPI
  module Models
    # Provides information on the client's token.
    class TokenInfo
      extend AttrPredicate

      # @return [Boolean] True if the tokeb is valid for authentication.
      attr_predicate :authenticated

      # @return [Boolean] True if the token has been revoked.
      attr_predicate :token_revoked

      # @return [User] The user associated with the token.
      attr_reader :user

      # @api private
      # @param [Hash] hash
      # @param [Connection] conn
      def initialize(hash, conn:)
        @authenticated = hash["authenticated"]
        @token_revoked = hash["is_token_revoked"]
        @user = Models::User.lazy_prepare(email: hash["email"], conn: conn)
      end
    end
  end
end
