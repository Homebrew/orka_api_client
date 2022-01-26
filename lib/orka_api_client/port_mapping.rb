# frozen_string_literal: true

module OrkaAPI
  # Represents a port forwarding from a host node to a guest VM.
  class PortMapping
    # @return [Integer] The port on the node side.
    attr_reader :host_port

    # @return [Integer] The port on the VM side.
    attr_reader :guest_port

    # @param [Integer] host_port The port on the node side.
    # @param [Integer] guest_port The port on the VM side.
    def initialize(host_port:, guest_port:)
      @host_port = host_port
      @guest_port = guest_port
    end
  end
end
