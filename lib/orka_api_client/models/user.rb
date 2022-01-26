# frozen_string_literal: true

require_relative "lazy_model"

module OrkaAPI
  module Models
    # To work with Orka, you need to have a user with an assigned license. You will use this user and the respective
    # credentials to authenticate against the Orka service. After being authenticated against the service, you can
    # run Orka API calls.
    class User < LazyModel
      # @return [String] The email address for the user.
      attr_reader :email

      # @return [String, nil] The group the user is in, if any.
      lazy_attr :group

      # @api private
      # @param [String] email
      # @param [Connection] conn
      # @return [User]
      def self.lazy_prepare(email:, conn:)
        new(conn: conn, email: email)
      end

      # @api private
      # @param [Connection] conn
      # @param [String] email
      # @param [String] group
      def initialize(conn:, email:, group: nil)
        super(!group.nil?)
        @conn = conn
        @email = email
        @group = if group == "$ungrouped"
          nil
        else
          group
        end
      end
      public_class_method :new

      # Delete the user in the endpoint. The user must have no Orka resources associated with them (other than their
      # authentication tokens). This operation invalidates all tokens associated with the user.
      #
      # @macro auth_token_and_license
      #
      # @return [void]
      def delete
        @conn.delete("users/#{@email}") do |r|
          r.options.context = {
            orka_auth_type: [:license, :token],
          }
        end
      end

      # Reset the password for the user. This operation is intended for administrators.
      #
      # @macro auth_token_and_license
      #
      # @param [String] password The new password for the user.
      # @return [void]
      def reset_password(password)
        body = {
          email:    email,
          password: password,
        }.compact
        @conn.post("users/password", body) do |r|
          r.options.context = {
            orka_auth_type: [:license, :token],
          }
        end
      end

      # Apply a group label to the user.
      #
      # @note This is a BETA feature.
      #
      # @macro auth_license
      #
      # @param [String] group The new group for the user.
      # @return [void]
      def change_group(group)
        @conn.post("users/groups/#{group || "$ungrouped"}", [@email]) do |r|
          r.options.context = {
            orka_auth_type: :license,
          }
        end
        @group = group
      end

      # Remove a group label from the user.
      #
      # @note This is a BETA feature.
      #
      # @macro auth_license
      #
      # @return [void]
      def remove_group
        change_group(nil)
      end

      private

      def lazy_initialize
        groups = @conn.get("users") do |r|
          r.options.context = {
            orka_auth_type: :license,
          }
        end.body["user_groups"]
        group = groups.find { |_, group_users| group_users.include?(@email) }&.first

        raise ResourceNotFoundError, "No user found matching \"#{@email}\"." if group.nil?

        @group = if group == "$ungrouped"
          nil
        else
          group
        end
        super
      end
    end
  end
end
