# frozen_string_literal: true

module OrkaAPI
  module Models
    # Information on a disk attached to a VM.
    class Disk
      # @return [String]
      attr_reader :type

      # @return [String]
      attr_reader :device

      # @return [String]
      attr_reader :target

      # @return [String]
      attr_reader :source

      # @api private
      # @param [String] type
      # @param [String] device
      # @param [String] target
      # @param [String] source
      def initialize(type:, device:, target:, source:)
        @type = type
        @device = device
        @target = target
        @source = source
      end
    end
  end
end
