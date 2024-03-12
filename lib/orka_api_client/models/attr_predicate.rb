# frozen_string_literal: true

module OrkaAPI
  module Models
    # @private
    module AttrPredicate
      private

      # @!parse
      #   # @!macro [attach] attr_predicate
      #   #  @!attribute [r] $1?
      #   def self.attr_predicate(*); end
      def attr_predicate(*attrs)
        attrs.each do |attr|
          define_method :"#{attr}?" do
            instance_variable_get(:"@#{attr}")
          end
        end
      end
    end
  end
end
