# frozen_string_literal: true

require_relative "lazy_model"

module OrkaAPI
  module Models
    # A template configuration (a container template) consisting of a
    # {https://orkadocs.macstadium.com/docs/orka-glossary#base-image base image}, a
    # {https://orkadocs.macstadium.com/docs/orka-glossary#snapshot-image snapshot image}, and the number of CPU cores
    # to be used. To become a VM that you can run in the cloud, a VM configuration needs to be deployed to a {Node
    # node}.
    #
    # You can deploy multiple VMs from a single VM configuration. Once created, you can no longer modify a VM
    # configuration.
    #
    # Deleting a VM does not delete the VM configuration it was deployed from.
    class VMConfiguration < LazyModel
      # @return [String] The name of this VM configuration.
      attr_reader :name

      # @return [User] The owner of this VM configuration, i.e. the user which deployed it.
      lazy_attr :owner

      # @return [Image] The base image which newly deployed VMs of this configuration will boot from.
      lazy_attr :base_image

      # @return [Integer] The number of CPU cores to allocate to deployed VMs of this configuration.
      lazy_attr :cpu_cores

      # @return [ISO] The ISO to attach to deployed VMs of this configuration.
      lazy_attr :iso_image

      # @return [Image] The storage disk image to attach to deployed VMs of this configuration.
      lazy_attr :attached_disk

      # @return [Boolean] True if the VNC console should be enabled for deployed VMs of this configuration.
      lazy_attr :vnc_console?

      # @return [Boolean] True if IO boost should be enabled for deployed VMs of this configuration.
      lazy_attr :io_boost?

      # @return [Boolean] True if deployed VMs of this configuration should use a prior saved state (created via
      #   {VMInstance#save_state}) rather than a clean base image.
      lazy_attr :use_saved_state?

      # @return [Boolean] True if GPU passthrough should be enabled for deployed VMs of this configuration.
      lazy_attr :gpu_passthrough?

      # @api private
      # @param [String] name
      # @param [Connection] conn
      # @return [VMConfiguration]
      def self.lazy_prepare(name:, conn:)
        new(conn: conn, name: name)
      end

      # @api private
      # @param [Hash] hash
      # @param [Connection] conn
      # @return [VMConfiguration]
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

      # Deploy the VM configuration to a node. If you don't specify a node, Orka chooses a node based on the
      # available resources.
      #
      # @macro auth_token
      #
      # @param [Node, String] node The node on which to deploy the VM. The node must have sufficient CPU and memory
      #   to accommodate the VM.
      # @param [Integer] replicas The scale at which to deploy the VM configuration. If not specified, defaults to
      #   +1+ (non-scaled).
      # @param [Array<PortMapping>] reserved_ports One or more port mappings that enable additional ports on your VM.
      # @param [Boolean] iso_install Set to +true+ if you want to use an ISO.
      # @param [Models::ISO, String] iso_image An ISO to attach to the VM during deployment. If already set in the
      #   respective VM configuration and not set here, Orka applies the setting from the VM configuration. You can
      #   also use this field to override any ISO specified in the VM configuration.
      # @param [Boolean] attach_disk Set to +true+ if you want to attach additional storage during deployment.
      # @param [Models::Image, String] attached_disk An additional storage disk to attach to the VM during
      #   deployment. If already set in the respective VM configuration and not set here, Orka applies the setting
      #   from the VM configuration. You can also use this field to override any storage specified in the VM
      #   configuration.
      # @param [Boolean] vnc_console Enables or disables VNC for the VM. If not set in the VM configuration or here,
      #   defaults to +true+. If already set in the respective VM configuration and not set here, Orka applies the
      #   setting from the VM configuration. You can also use this field to override the VNC setting specified in the
      #   VM configuration.
      # @param [Hash{String => String}] vm_metadata Inject custom metadata to the VM. If not set, only the built-in
      #   metadata is injected into the VM.
      # @param [String] system_serial Assign an owned macOS system serial number to the VM. If already set in the
      #   respective VM configuration and not set here, Orka applies the setting from the VM configuration.
      # @param [Boolean] gpu_passthrough Enables or disables GPU passthrough for the VM. If not set in the VM
      #   configuration or here, defaults to +false+. If already set in the respective VM configuration and not set
      #   here, Orka applies the setting from the VM configuration. You can also use this field to override the GPU
      #   passthrough setting specified in the VM configuration. When enabled, +vnc_console+ is automatically
      #   disabled. GPU passthrough is an experimental feature. GPU passthrough must first be enabled in your
      #   cluster.
      # @return [VMDeploymentResult] Details of the just-deployed VM.
      def deploy(node: nil, replicas: nil, reserved_ports: nil, iso_install: nil,
                 iso_image: nil, attach_disk: nil, attached_disk: nil, vnc_console: nil,
                 vm_metadata: nil, system_serial: nil, gpu_passthrough: nil)
        VMResource.lazy_prepare(name: @name, conn: @conn).deploy(
          node:            node,
          replicas:        replicas,
          reserved_ports:  reserved_ports,
          iso_install:     iso_install,
          iso_image:       iso_image,
          attach_disk:     attach_disk,
          attached_disk:   attached_disk,
          vnc_console:     vnc_console,
          vm_metadata:     vm_metadata,
          system_serial:   system_serial,
          gpu_passthrough: gpu_passthrough,
        )
      end

      # Remove the VM configuration and all VM deployments of it.
      #
      # If the VM configuration and its deployments belong to the user associated with the client's token then the
      # client only needs to be configured with a token. Otherwise, if you are removing a VM resource associated with
      # another user, you need to configure the client with both a token and a license key.
      #
      # @return [void]
      def purge
        VMResource.lazy_prepare(name: @name, conn: @conn).purge
      end

      # Delete the VM configuration state. Now when you deploy the VM configuration it will use the base image to
      # boot the VM.
      #
      # To delete a VM state, it must not be used by any deployed VM.
      #
      # @macro auth_token
      #
      # @return [void]
      def delete_saved_state
        @conn.delete("resources/vm/configs/#{@name}/delete-state") do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
      end

      private

      def lazy_initialize
        response = @conn.get("resources/vm/configs/#{@name}") do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
        configs = response.body["configs"]

        raise ResourceNotFoundError, "No VM configuration found matching \"#{@name}\"." if configs.empty?

        deserialize(configs.first)
        super
      end

      def deserialize(hash)
        @name = hash["orka_vm_name"]
        @owner = User.lazy_prepare(email: hash["owner"], conn: @conn)
        @base_image = Image.lazy_prepare(name: hash["orka_base_image"], conn: @conn)
        @cpu_cores = hash["orka_cpu_core"]
        @iso_image = if hash["iso_image"] == "None"
          nil
        else
          ISO.lazy_prepare(name: hash["iso_image"], conn: @conn)
        end
        @attached_disk = if hash["attached_disk"] == "None"
          nil
        else
          Image.lazy_prepare(name: hash["attached_disk"], conn: @conn)
        end
        @vnc_console = hash["vnc_console"]
        @io_boost = hash["io_boost"]
        @use_saved_state = hash["use_saved_state"]
        @gpu_passthrough = hash["gpu_passthrough"]
      end
    end
  end
end
