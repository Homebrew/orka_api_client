# frozen_string_literal: true

require_relative "attr_predicate"

module OrkaAPI
  module Models
    # Provides information on the just-deployed VM.
    class VMDeploymentResult
      extend AttrPredicate

      # @return [String] The amount of RAM allocated to the VM.
      attr_reader :ram

      # @return [Integer] The number of vCPUs allocated to the VM.
      attr_reader :vcpu_count

      # @return [Integer] The number of host CPU cores allocated to the VM.
      attr_reader :cpu_cores

      # @return [String] The IP of the VM.
      attr_reader :ip

      # @return [Integer] The port used to connect to the VM via SSH.
      attr_reader :ssh_port

      # @return [Integer] The port used to connect to the VM via macOS Screen Sharing.
      attr_reader :screen_sharing_port

      # @return [VMResource] The VM resource object representing this VM.
      attr_reader :resource

      # @return [Boolean] True if IO boost is enabled for this VM.
      attr_predicate :io_boost

      # @return [Boolean] True if this VM is using a prior saved state rather than a clean base image.
      attr_predicate :use_saved_state

      # @return [Boolean] True if GPU passthrough is enabled for this VM.
      attr_predicate :gpu_passthrough

      # @return [Integer, nil] The port used to connect to the VM via VNC, if enabled.
      attr_reader :vnc_port

      # @api private
      # @param [Hash] hash
      # @param [Connection] conn
      # @param [Boolean] admin
      def initialize(hash, conn:, admin: false)
        @ram = hash["ram"]
        @vcpu_count = hash["vcpu"].to_i
        @cpu_cores = hash["host_cpu"].to_i
        @ip = hash["ip"]
        @ssh_port = hash["ssh_port"].to_i
        @screen_sharing_port = hash["screen_share_port"].to_i
        @resource = Models::VMResource.lazy_prepare(name: hash["vm_id"], conn: conn, admin: admin)
        # TODO: port_warnings?
        @io_boost = hash["io_boost"]
        @use_saved_state = if hash["use_saved_state"] == "N/A"
          false
        else
          hash["use_saved_state"]
        end
        @gpu_passthrough = if hash["gpu_passthrough"] == "N/A"
          false
        else
          hash["gpu_passthrough"]
        end
        @vnc_port = if hash["vnc_port"] == "N/A"
          nil
        else
          hash["vnc_port"].to_i
        end
      end
    end
  end
end
