# frozen_string_literal: true

module OrkaAPI
  module Models
    # An account used for Kubernetes operations.
    class KubeAccount
      # @return [String] The name of this kube-account.
      attr_reader :name

      # @api private
      # @param [String] name
      # @param [String] email
      # @param [String] kubeconfig
      # @param [Connection] conn
      def initialize(name, conn:, email: nil, kubeconfig: nil)
        @name = name
        @email = email
        @kubeconfig = kubeconfig
        @conn = conn
      end

      # Regenerate this kube-account.
      #
      # @macro auth_token_and_license
      #
      # @return [void]
      def regenerate
        body = {
          name:  name,
          email: email,
        }.compact
        @kubeconfig = @conn.post("resources/kube-account/regenerate", body) do |r|
          r.options.context = {
            orka_auth_type: [:token, :license],
          }
        end.body["kubeconfig"]
      end

      # Retrieve the +kubeconfig+ for this kube-account.
      #
      # This method is cached. Subsequent calls to this method will not invoke additional network requests. The
      # methods {#regenerate} and {Client#create_kube_account} also fill this cache.
      #
      # @macro auth_token_and_license
      #
      # @return [void]
      def kubeconfig
        return @kubeconfig unless @kubeconfig.nil?

        @kubeconfig = @conn.get("resources/kube-account/download") do |r|
          r.body = {
            name:  @name,
            email: @email,
          }.compact

          r.options.context = {
            orka_auth_type: [:token, :license],
          }
        end.body["@kubeconfig"]
      end
    end
  end
end
