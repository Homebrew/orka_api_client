# frozen_string_literal: true

require_relative "lazy_model"
require_relative "vm_instance"

module OrkaAPI
  module Models
    # A general representation of {VMConfiguration VM configurations} and the {VMInstance VMs} deployed from those
    # configurations.
    class VMResource < LazyModel
      # @return [String] The name of this VM resource.
      attr_reader :name

      # @return [Boolean] True if there are associated deployed VM instances.
      lazy_attr :deployed?

      # @return [Array<VMInstance>] The list of deployed VM instances.
      lazy_attr :instances

      # @return [User, nil] The owner of the associated VM configuration. This is +nil+ if {#deployed?} is +true+.
      lazy_attr :owner

      # @return [Integer, nil] The number of CPU cores to use, specified by the associated VM configuration. This is
      #   +nil+ if {#deployed?} is +true+.
      lazy_attr :cpu

      # @return [Integer, nil] The number of vCPUs to use, specified by the associated VM configuration. This is
      #   +nil+ if {#deployed?} is +true+.
      lazy_attr :vcpu

      # @return [Image, nil] The base image to use, specified by the associated VM configuration. This is +nil+ if
      #   {#deployed?} is +true+.
      lazy_attr :base_image

      # @return [VMConfiguration, nil] The matching VM configuration object. This is +nil+ if {#deployed?} is +true+.
      lazy_attr :config

      # @return [Boolean, nil] True if IO boost is enabled, specified by the associated VM configuration. This is
      #   +nil+ if {#deployed?} is +true+.
      lazy_attr :io_boost?

      # @return [Boolean, nil] True if the saved state should be used rather than cleanly from the base image,
      #   specified by the associated VM configuration. This is +nil+ if {#deployed?} is +true+.
      lazy_attr :use_saved_state?

      # @return [Boolean, nil] True if GPU passthrough is enabled, specified by the associated VM configuration. This
      #   is +nil+ if {#deployed?} is +true+.
      lazy_attr :gpu_passthrough?

      # @return [String, nil]
      lazy_attr :configuration_template

      # @api private
      # @param [String] name
      # @param [Connection] conn
      # @param [Boolean] admin
      # @return [VMResource]
      def self.lazy_prepare(name:, conn:, admin: false)
        new(conn: conn, name: name, admin: admin)
      end

      # @api private
      # @param [Hash] hash
      # @param [Connection] conn
      # @param [Boolean] admin
      # @return [VMResource]
      def self.from_hash(hash, conn:, admin: false)
        new(conn: conn, hash: hash, admin: admin)
      end

      # @private
      # @param [Connection] conn
      # @param [String] name
      # @param [Hash] hash
      # @param [Boolean] admin
      def initialize(conn:, name: nil, hash: nil, admin: false)
        super(!hash.nil?)
        @conn = conn
        @name = name
        @admin = admin
        deserialize(hash) if hash
      end

      # @!macro [new] vm_resource_state_note
      #   @note Calling this will not change the state of this object, and thus not change the return values of
      #     {#deployed?} and {#instances}, if the object already been loaded. You must fetch a new object instance or
      #     call {#refresh} to refresh this data.

      # Deploy an existing VM configuration to a node. If you don't specify a node, Orka chooses a node based on the
      # available resources.
      #
      # @macro auth_token
      #
      # @macro vm_resource_state_note
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
      # @return [void]
      def deploy(node: nil, replicas: nil, reserved_ports: nil, iso_install: nil,
                 iso_image: nil, attach_disk: nil, attached_disk: nil, vnc_console: nil,
                 vm_metadata: nil, system_serial: nil, gpu_passthrough: nil)
        vm_metadata = { items: vm_metadata.map { |k, v| { key: k, value: v } } } unless vm_metadata.nil?
        body = {
          orka_vm_name:    @name,
          orka_node_name:  node.is_a?(Node) ? node.name : node,
          replicas:        replicas,
          reserved_ports:  reserved_ports&.map { |mapping| "#{mapping.host_port}:#{mapping.guest_port}" },
          iso_install:     iso_install,
          iso_image:       iso_image.is_a?(ISO) ? iso_image.name : iso_image,
          attach_disk:     attach_disk,
          attached_disk:   attached_disk.is_a?(Image) ? attached_disk.name : attached_disk,
          vnc_console:     vnc_console,
          vm_metadata:     vm_metadata,
          system_serial:   system_serial,
          gpu_passthrough: gpu_passthrough,
        }.compact
        @conn.post("resources/vm/deploy", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
      end

      # Removes all VM instances.
      #
      # If the VM instances belongs to the user associated with the client's token then the client only needs to be
      # configured with a token. Otherwise, if you are removing VM instances associated with another user, you need
      # to configure the client with both a token and a license key.
      #
      # @macro vm_resource_state_note
      #
      # @param [Node, String] node If specified, only remove VM deployments on that node.
      # @return [void]
      def delete_all_instances(node: nil)
        @conn.delete("resources/vm/delete") do |r|
          r.body = {
            orka_vm_name:   @name,
            orka_node_name: node.is_a?(Node) ? node.name : node,
          }.compact

          auth_type = [:token]
          auth_type << :license if @admin
          r.options.context = {
            orka_auth_type: auth_type,
          }
        end
      rescue Faraday::ServerError => e
        raise unless e.response[:body]&.include?("No VMs with that name are currently deployed")
      end

      # Remove all VM instances and the VM configuration.
      #
      # If the VM resource belongs to the user associated with the client's token then the client only needs to be
      # configured with a token. Otherwise, if you are removing a VM resource associated with another user, you need
      # to configure the client with both a token and a license key.
      #
      # @macro vm_resource_state_note
      #
      # @return [void]
      def purge
        @conn.delete("resources/vm/purge") do |r|
          r.body = {
            orka_vm_name: @name,
          }.compact

          auth_type = [:token]
          auth_type << :license if @admin
          r.options.context = {
            orka_auth_type: auth_type,
          }
        end
      end

      # Power ON all VM instances on a particular node that are associated with this VM resource.
      #
      # @macro auth_token
      #
      # @macro vm_resource_state_note
      #
      # @param [Node, String] node All deployments of this VM located on this node will be started.
      # @return [void]
      def start_all_on_node(node)
        raise ArgumentError, "Node cannot be nil." if node.nil?

        body = {
          orka_vm_name:   @name,
          orka_node_name: node.is_a?(Node) ? node.name : node,
        }.compact
        @conn.post("resources/vm/exec/start", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
      end

      # Power OFF all VM instances on a particular node that are associated with this VM resource.
      #
      # @macro auth_token
      #
      # @macro vm_resource_state_note
      #
      # @param [Node, String] node All deployments of this VM located on this node will be stopped.
      # @return [void]
      def stop_all_on_node(node)
        raise ArgumentError, "Node cannot be nil." if node.nil?

        body = {
          orka_vm_name:   @name,
          orka_node_name: node.is_a?(Node) ? node.name : node,
        }.compact
        @conn.post("resources/vm/exec/stop", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
      end

      # Suspend all VM instances on a particular node that are associated with this VM resource.
      #
      # @macro auth_token
      #
      # @macro vm_resource_state_note
      #
      # @param [Node, String] node All deployments of this VM located on this node will be suspended.
      # @return [void]
      def suspend_all_on_node(node)
        raise ArgumentError, "Node cannot be nil." if node.nil?

        body = {
          orka_vm_name:   @name,
          orka_node_name: node.is_a?(Node) ? node.name : node,
        }.compact
        @conn.post("resources/vm/exec/suspend", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
      end

      # Resume all VM instances on a particular node that are associated with this VM resource.
      #
      # @macro auth_token
      #
      # @macro vm_resource_state_note
      #
      # @param [Node, String] node All deployments of this VM located on this node will be resumed.
      # @return [void]
      def resume_all_on_node(node)
        raise ArgumentError, "Node cannot be nil." if node.nil?

        body = {
          orka_vm_name:   @name,
          orka_node_name: node.is_a?(Node) ? node.name : node,
        }.compact
        @conn.post("resources/vm/exec/resume", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
      end

      # Revert all VM instances on a particular node that are associated with this VM resource to the latest state of
      # its base image. This operation restarts the VMs.
      #
      # @macro auth_token
      #
      # @macro vm_resource_state_note
      #
      # @param [Node, String] node All deployments of this VM located on this node will be reverted.
      # @return [void]
      def revert_all_on_node(node)
        raise ArgumentError, "Node cannot be nil." if node.nil?

        body = {
          orka_vm_name:   @name,
          orka_node_name: node.is_a?(Node) ? node.name : node,
        }.compact
        @conn.post("resources/vm/exec/revert", body) do |r|
          r.options.context = {
            orka_auth_type: :token,
          }
        end
      end

      private

      def lazy_initialize
        response = @conn.get("resources/vm/status/#{@name}") do |r|
          auth_type = [:token]
          auth_type << :license if @admin
          r.options.context = {
            orka_auth_type: auth_type,
          }
        end
        resources = response.body["virtual_machine_resources"]

        raise ResourceNotFoundError, "No VM resource found matching \"#{@name}\"." if resources.empty?

        deserialize(resources.first)
        super
      end

      def deserialize(hash)
        @name = hash["virtual_machine_name"]
        @deployed = case hash["vm_deployment_status"]
        when "Deployed"
          true
        when "Not Deployed"
          false
        else
          raise UnrecognisedStateError, "Unrecognised VM deployment status."
        end

        if @deployed
          @instances = hash["status"].map { |instance| VMInstance.new(instance, conn: @conn, admin: @admin) }
        else
          @instances = []
          @owner = User.lazy_prepare(email: hash["owner"], conn: @conn)
          @cpu = hash["cpu"]
          @vcpu = hash["vcpu"]
          @base_image = Image.lazy_prepare(name: hash["base_image"], conn: @conn)
          @config = VMConfiguration.lazy_prepare(name: hash["image"], conn: @conn)
          @io_boost = hash["io_boost"]
          @use_saved_state = hash["use_saved_state"]
          @gpu_passthrough = hash["gpu_passthrough"]
          @configuration_template = hash["configuration_template"]
        end
      end
    end
  end
end
