# frozen_string_literal: true

require_relative "lazy_model"
require_relative "protocol_port_mapping"

module OrkaAPI
  module Models
    # A physical or logical host that provides computational resources for your VMs. Usually, an Orka node is a
    # genuine Apple physical host with a host OS on top. You have no direct access (via VNC, SSH, or Screen Sharing)
    # to your nodes.
    class Node < LazyModel
      # @return [String] The name of this node.
      attr_reader :name

      # @return [String] The host name of this node.
      lazy_attr :host_name

      # @return [String] The IP address of this node.
      lazy_attr :address

      # @return [String] The host IP address of this node.
      lazy_attr :host_ip

      # @return [Integer] The number of free CPU cores on this node.
      lazy_attr :available_cpu_cores

      # @return [Integer] The total number of CPU cores on this node that are allocatable to VMs.
      lazy_attr :allocatable_cpu_cores

      # @return [Integer] The number of free GPUs on this node.
      lazy_attr :available_gpu_count

      # @return [Integer] The total number of GPUs on this node that are allocatable to VMs.
      lazy_attr :allocatable_gpu_count

      # @return [String] The amount of free RAM on this node.
      lazy_attr :available_memory

      # @return [Integer] The total number of CPU cores on this node.
      lazy_attr :total_cpu_cores

      # @return [String] The total amount of RAM on this node.
      lazy_attr :total_memory

      # @return [String] The type of this node (WORKER, FOUNDATION, SANDBOX).
      lazy_attr :type

      # @return [String] The state of this node.
      lazy_attr :state

      # @return [String, nil] The user group this node is dedicated to, if any.
      lazy_attr :orka_group

      # @return [Array<String>] The list of tags this node has been assigned.
      lazy_attr :tags

      # @api private
      # @param [String] name
      # @param [Connection] conn
      # @param [Boolean] admin
      # @return [Node]
      def self.lazy_prepare(name:, conn:, admin: false)
        new(conn: conn, name: name, admin: admin)
      end

      # @api private
      # @param [Hash] hash
      # @param [Connection] conn
      # @param [Boolean] admin
      # @return [Node]
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

      # Get a detailed list of all reserved ports on this node. Orka lists them as port mappings between
      # {ProtocolPortMapping#host_port host_port} and {ProtocolPortMapping#guest_port guest_port}.
      # {ProtocolPortMapping#host_port host_port} indicates a port on the node, {ProtocolPortMapping#guest_port
      # guest_port} indicates a port on a VM on this node.
      #
      # @macro auth_token
      #
      # @macro lazy_enumerator
      #
      # @return [Enumerator<ProtocolPortMapping>] The enumerator of the reserved ports list.
      def reserved_ports
        Enumerator.new do
          all_ports = @conn.get("resources/ports") do |r|
            r.options.context = {
              orka_auth_type: :token,
            }
          end.body["reserved_ports"]

          node_ports = all_ports.select do |hash|
            hash["orka_node_name"] == @name
          end

          node_ports.map do |mapping|
            ProtocolPortMapping.new(
              host_port:  mapping["host_port"],
              guest_port: mapping["guest_port"],
              protocol:   mapping["protocol"],
            )
          end
        end
      end

      # Tag this node as sandbox. This limits deployment management from the Orka CLI. You can perform only
      # Kubernetes deployment management with +kubectl+, {https://helm.sh/docs/helm/#helm Helm}, and Tiller.
      #
      # @macro auth_token_and_license
      #
      # @note This request is supported for Intel nodes only.
      #
      # @return [void]
      def enable_sandbox
        body = {
          orka_node_name: @name,
        }.compact
        @conn.post("resources/node/sandbox", body) do |r|
          r.options.context = {
            orka_auth_type: [:license, :token],
          }
        end
      end

      # Remove the sandbox tag from this node. This re-enables deployment management with the Orka CLI.
      #
      # @macro auth_token_and_license
      #
      # @note This request is supported for Intel nodes only.
      #
      # @return [void]
      def disable_sandbox
        @conn.delete("resources/node/sandbox") do |r|
          r.body = {
            orka_node_name: @name,
          }.compact

          r.options.context = {
            orka_auth_type: [:license, :token],
          }
        end
      end

      # Dedicate this node to a specified user group. Only users from this user group will be able to deploy to the
      # node.
      #
      # @macro auth_token_and_license
      #
      # @param [String, nil] group The user group to dedicate the node to.
      # @return [void]
      def dedicate_to_group(group)
        body = [@name].compact
        @conn.post("resources/node/groups/#{group || "$ungrouped"}", body) do |r|
          r.options.context = {
            orka_auth_type: [:license, :token],
          }
        end
        @orka_group = group
      end

      # Make this node available to all users.
      #
      # @macro auth_token_and_license
      #
      # @return [void]
      def remove_group_dedication
        dedicate_to_group(nil)
      end

      # Assign the specified tag to the specified node (enable node affinity). When node affinity is configured,
      # Orka first attempts to deploy to the specified node or group of nodes, before moving to any other nodes.
      #
      # @macro auth_token_and_license
      #
      # @param [String] tag_name The name of the tag.
      # @return [void]
      def tag(tag_name)
        body = {
          orka_node_name: @name,
        }.compact
        @conn.post("resources/node/tag/#{tag_name}", body) do |r|
          r.options.context = {
            orka_auth_type: [:license, :token],
          }
        end
        @tags << tag_name
      end

      # Remove the specified tag from the specified node.
      #
      # @macro auth_token_and_license
      #
      # @param [String] tag_name The name of the tag.
      # @return [void]
      def untag(tag_name)
        @conn.delete("resources/node/tag/#{tag_name}") do |r|
          r.body = {
            orka_node_name: @name,
          }.compact

          r.options.context = {
            orka_auth_type: [:license, :token],
          }
        end
        @tags.delete(tag_name)
      end

      private

      def lazy_initialize
        # We don't use /resources/node/status/{name} as it only provides partial data.
        url = "resources/node/list"
        url += "/all" if @admin
        response = @conn.get(url) do |r|
          auth_type = [:token]
          auth_type << :license if @admin
          r.options.context = {
            orka_auth_type: auth_type,
          }
        end
        node = response.body["nodes"].find { |hash| hash["name"] == @name }

        raise ResourceNotFoundError, "No node found matching \"#{@name}\"." if node.nil?

        deserialize(node)
        super
      end

      def deserialize(hash)
        @name = hash["name"]
        @host_name = hash["host_name"]
        @address = hash["address"]
        @host_ip = hash["hostIP"]
        @available_cpu_cores = hash["available_cpu"]
        @allocatable_cpu_cores = hash["allocatable_cpu"]
        @available_gpu_count = if hash["available_gpu"] == "N/A"
          0
        else
          hash["available_gpu"].to_i
        end
        @allocatable_gpu_count = if hash["allocatable_gpu"] == "N/A"
          0
        else
          hash["allocatable_gpu"].to_i
        end
        @available_memory = hash["available_memory"]
        @total_cpu_cores = hash["total_cpu"]
        @total_memory = hash["total_memory"]
        @type = hash["node_type"]
        @state = hash["state"]
        @orka_group = hash["orka_group"]
        @tags = hash["orka_tags"]
      end
    end
  end
end
