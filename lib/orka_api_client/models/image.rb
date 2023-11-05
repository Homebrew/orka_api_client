# frozen_string_literal: true

require_relative "lazy_model"

module OrkaAPI
  module Models
    # A disk image that represents a VM's storage and its contents, including the OS and any installed software.
    class Image < LazyModel
      # @return [String] The name of this image.
      attr_reader :name

      # @return [String] The size of this image. Orka lists generated empty storage disks with a fixed size of ~192k.
      #   When attached to a VM and formatted, the disk will appear with its correct size in the OS.
      lazy_attr :size

      # @return [DateTime] The time this image was last modified.
      lazy_attr :modification_time

      # @return [DateTime, nil] The time this image was first created, if available.
      lazy_attr :creation_time

      # @return [String]
      lazy_attr :owner

      # @api private
      # @param [String] name
      # @param [Connection] conn
      # @return [Image]
      def self.lazy_prepare(name:, conn:)
        new(conn: conn, name: name)
      end

      # @api private
      # @param [Hash] hash
      # @param [Connection] conn
      # @return [Image]
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

      # Rename this image.
      #
      # @macro auth_token
      #
      # @note After you rename a base image, you can no longer deploy any VM configurations that are based on the
      #   image of the old name.
      #
      # @param [String] new_name The new name for this image.
      # @return [void]
      def rename(new_name)
        body = {
          image:    @name,
          new_name: new_name,
        }.compact
        @conn.post("resources/image/rename", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
        @name = new_name
      end

      # Copy this image to a new one.
      #
      # @macro auth_token
      #
      # @param [String] new_name The name for the copy of this image.
      # @return [Image] The lazily-loaded image copy.
      def copy(new_name)
        body = {
          image:    @name,
          new_name: new_name,
        }.compact
        @conn.post("resources/image/copy", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
        Image.lazy_prepare(name: new_name, conn: @conn)
      end

      # Delete this image from the local Orka storage.
      #
      # @macro auth_token
      #
      # @note Make sure that the image is not in use.
      #
      # @return [void]
      def delete
        body = {
          image: @name,
        }.compact
        @conn.post("resources/image/delete", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
      end

      # Download this image from Orka cluster storage to your local filesystem.
      #
      # @macro auth_token
      #
      # @note This request is supported for Intel images only. Intel images have +.img+ extension.
      #
      # @param [String, Pathname, IO] to An open IO, or a String/Pathname file path to the file or directory where
      #   you want the image to be written.
      # @return [void]
      def download(to:)
        io_input = to.is_a?(::IO)
        file = if io_input
          to
        else
          to = File.join(to, @name) if File.directory?(to)
          File.open(to, "wb:ASCII-8BIT")
        end
        @conn.get("resources/image/download/#{@name}") do |r|
          r.options.context = {
            orka_auth_type: :token,
          }

          r.options.on_data = proc do |chunk, _|
            file.write(chunk)
          end
        end
      ensure
        file.close unless io_input
      end

      # Request the MD5 file checksum for this image in Orka cluster storage. The checksum can be used to verify file
      # integrity for a downloaded or uploaded image.
      #
      # @macro auth_token
      #
      # @note This request is supported for Intel images only. Intel images have +.img+ extension.
      #
      # @return [String, nil] The MD5 checksum of the image, or nil if the calculation is in progress and has not
      #   completed.
      def checksum
        @conn.get("resources/image/checksum/#{@name}") do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end.body&.dig("checksum")
      end

      private

      def lazy_initialize
        response = @conn.get("resources/image/list") do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
        image = response.body["image_attributes"].find { |hash| hash["image"] == @name }

        raise ResourceNotFoundError, "No image found matching \"#{@name}\"." if image.nil?

        deserialize(image)
        super
      end

      def deserialize(hash)
        @name = hash["image"]
        @size = hash["image_size"]
        @modification_time = DateTime.iso8601(hash["modified"])
        @creation_time = if hash["date_added"] == "N/A"
          nil
        else
          DateTime.iso8601(hash["date_added"])
        end
        @owner = hash["owner"]
      end
    end
  end
end
