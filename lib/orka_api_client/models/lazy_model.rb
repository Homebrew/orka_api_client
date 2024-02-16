# frozen_string_literal: true

module OrkaAPI
  module Models
    # The base class for lazily-loaded objects.
    class LazyModel
      # @!macro [attach] lazy_attr
      #   @!attribute [r]
      def self.lazy_attr(*attrs)
        attrs.each do |attr|
          define_method attr do
            ivar = "@#{attr.to_s.delete_suffix("?")}"
            existing = instance_variable_get(ivar)
            return existing unless existing.nil?

            eager
            instance_variable_get(ivar)
          end
        end
      end
      private_class_method :lazy_attr

      # @private
      # @param [Boolean] lazy_initialized
      def initialize(lazy_initialized)
        @lazy_initialized = lazy_initialized
      end
      private_class_method :new

      # Forces this lazily-loaded object to be fully loaded, performing any necessary network operations.
      #
      # @return [self]
      def eager
        lazy_initialize unless @lazy_initialized
        self
      end

      # Re-fetches this object's data from the Orka API. This will raise an error if the object no longer exists.
      #
      # @return [void]
      def refresh
        lazy_initialize
      end

      private

      def lazy_initialize
        @lazy_initialized = true
      end
    end
  end
end
