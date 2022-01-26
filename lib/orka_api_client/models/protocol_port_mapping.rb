# frozen_string_literal: true

require_relative "../port_mapping"

module OrkaAPI
  module Models
    # Represents a port forwarding from a host node to a guest VM, with an additional field denoting the transport
    # protocol.
    class ProtocolPortMapping < PortMapping
      # @return [String] The transport protocol, typically TCP.
      attr_reader :protocol

      # @api private
      # @param [Integer] host_port
      # @param [Integer] guest_port
      # @param [String] protocol
      def initialize(host_port:, guest_port:, protocol:)
        super(host_port: host_port, guest_port: guest_port)
        @protocol = protocol
      end
    end
  end
end
