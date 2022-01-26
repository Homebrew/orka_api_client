# frozen_string_literal: true

module OrkaAPI
  module Models
    # Enumerator subclass for networked operations.
    class Enumerator < ::Enumerator
      # @api private
      def initialize
        super do |yielder|
          yield.each do |item|
            yielder << item
          end
        end
      end

      # Forces this lazily-loaded enumerator to be fully loaded, peforming any necessary network operations.
      #
      # @return [self]
      def eager
        begin
          peek
        rescue StopIteration
          # We're fine if the enuemrator is empty.
        end
        self
      end
    end
  end
end
