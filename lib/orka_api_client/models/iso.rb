# frozen_string_literal: true

require_relative "lazy_model"

module OrkaAPI
  module Models
    # An +.iso+ disk image used exclusively for the installation of macOS on a virtual machine. You must attach the
    # ISO to the VM during deployment. After the installation is complete and the VM has booted successfully, you
    # need to restart the VM to detach the ISO.
    #
    # @note All ISO requests are supported for Intel nodes only.
    class ISO < LazyModel
      # @return [String] The name of this ISO.
      attr_reader :name

      # @return [String] The size of this ISO.
      lazy_attr :size

      # @return [DateTime] The time this image was last modified.
      lazy_attr :modification_time

      # @api private
      # @param [String] name
      # @param [Connection] conn
      # @return [ISO]
      def self.lazy_prepare(name:, conn:)
        new(conn: conn, name: name)
      end

      # @api private
      # @param [Hash] hash
      # @param [Connection] conn
      # @return [ISO]
      def self.from_hash(hash, conn:)
        new(conn: conn, hash: hash)
      end

      # @private
      # @param [Connection] conn
      # @param [String] name
      # @param [Hash] hash
      def initialize(conn:, name: nil, hash: nil)
        super(!hash.nil?)
        @conn = conn
        @name = name
        deserialize(hash) if hash
      end

      # Rename this ISO.
      #
      # @macro auth_token
      #
      # @note Make sure that the ISO is not in use. Any VMs that have the ISO of the old name attached will no longer
      #   be able to boot from it.
      #
      # @param [String] new_name The new name for this ISO.
      # @return [void]
      def rename(new_name)
        body = {
          iso:      @name,
          new_name: new_name,
        }.compact
        @conn.post("resources/iso/rename", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
        @name = new_name
      end

      # Copy this ISO to a new one.
      #
      # @macro auth_token
      #
      # @param [String] new_name The name for the copy of this ISO.
      # @return [Image] The lazily-loaded ISO copy.
      def copy(new_name)
        body = {
          iso:      @name,
          new_name: new_name,
        }.compact
        @conn.post("resources/iso/copy", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
        ISO.lazy_prepare(new_name, conn: @conn)
      end

      # Delete this ISO from the local Orka storage.
      #
      # @macro auth_token
      #
      # @note Make sure that the ISO is not in use. Any VMs that have the ISO attached will no longer be able to boot
      #   from it.
      #
      # @return [void]
      def delete
        body = {
          iso: @name,
        }.compact
        @conn.post("resources/iso/delete", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
      end

      private

      def lazy_initialize
        response = @conn.get("resources/iso/list") do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
        iso = response.body["iso_attributes"].find { |hash| hash["iso"] == @name }

        raise ResourceNotFoundError, "No ISO found matching \"#{@name}\"." if iso.nil?

        deserialize(iso)
        super
      end

      def deserialize(hash)
        @name = hash["iso"]
        @size = hash["iso_size"]
        @modification_time = DateTime.iso8601(hash["modified"])
      end
    end
  end
end
