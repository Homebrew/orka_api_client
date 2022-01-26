# frozen_string_literal: true

module OrkaAPI
  module Models
    # Represents an image which exists in the Orka remote repo rather than local storage.
    class RemoteImage
      # @return [String] The name of this remote image.
      attr_reader :name

      # @api private
      # @param [String] name
      # @param [Connection] conn
      def initialize(name, conn:)
        @name = name
        @conn = conn
      end

      # Pull this image from the remote repo. This is a long-running operation and might take a while.
      #
      # The operation copies the image to the local storage of your Orka environment. The base image will be
      # available for use by all users of the environment.
      #
      # @macro auth_token
      #
      # @param [String] new_name The name for the local copy of this image.
      # @return [Image] The lazily-loaded local image.
      def pull(new_name)
        body = {
          image:    @name,
          new_name: new_name,
        }.compact
        @conn.post("resources/image/pull", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
        Image.lazy_prepare(name: new_name, conn: @conn)
      end
    end
  end
end
