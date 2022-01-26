# frozen_string_literal: true

module OrkaAPI
  module Models
    # Represents an ISO which exists in the Orka remote repo rather than local storage.
    class RemoteISO
      # @return [String] The name of this remote ISO.
      attr_reader :name

      # @api private
      # @param [String] name
      # @param [Connection] conn
      def initialize(name, conn:)
        @name = name
        @conn = conn
      end

      # Pull an ISO from the remote repo. You can retain the ISO name or change it during the operation. This is a
      # long-running operation and might take a while.
      #
      # The operation copies the ISO to the local storage of your Orka environment. The ISO will be available for use
      # by all users of the environment.
      #
      # @macro auth_token
      #
      # @param [String] new_name The name for the local copy of this ISO.
      # @return [ISO] The lazily-loaded local ISO.
      def pull(new_name)
        body = {
          image:    @name,
          new_name: new_name,
        }.compact
        @conn.post("resources/iso/pull", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
        ISO.lazy_prepare(name: new_name, conn: @conn)
      end
    end
  end
end
