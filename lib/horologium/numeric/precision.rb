# frozen_string_literal: true

module Horologium
  module Numeric
    # The precision a value computes with: +:standard+, the fast two-part float
    # ({TwoPartFloat}), or +:exact+, the lossless Rational ({Exact}). This
    # module holds the rules that decide the precision of a result and coerce a
    # value from one precision into another.
    #
    # The rule for a result is that exactness is contagious: an operation
    # between two +:standard+ values stays +:standard+, but mixing +:standard+
    # with +:exact+ promotes to +:exact+ rather than dropping to +:standard+.
    # Promotion is lossless, since a two-part float pair is an exact Rational;
    # what +:exact+ certifies is the arithmetic from that point on, not the
    # precision of an input built before it.
    #
    # @api private
    module Precision
      # The recognised precisions.
      NAMES = %i[standard exact].freeze

      class << self
        # Checks that a precision is recognised and returns it.
        #
        # @param precision [Symbol] the precision to check
        # @return [Symbol] the same precision
        # @raise [UnknownPrecisionError] when it is not one of {NAMES}
        def validate!(precision)
          return precision if NAMES.include?(precision)

          raise UnknownPrecisionError.new(precision, NAMES)
        end

        # The precision a result takes from its two operands. Same precision
        # passes through; a mix of +:standard+ and +:exact+ promotes to
        # +:exact+.
        #
        # @param left [Symbol] one operand's precision
        # @param right [Symbol] the other operand's precision
        # @return [Symbol] the result's precision
        # @raise [UnknownPrecisionError] when either is not recognised
        def resolve(left, right)
          validate!(left)
          validate!(right)
          return :exact if left == :exact || right == :exact

          :standard
        end

        # Coerces a numeric value into a precision, losslessly. Promoting a
        # +:standard+ value to +:exact+ keeps its exact value; a value already
        # in the target precision is returned unchanged. There is no lossy
        # path: the contagion rule never asks to move an +:exact+ value down to
        # +:standard+, so that request is refused.
        #
        # @param value [TwoPartFloat, Exact] the value to coerce
        # @param to [Symbol] the target precision
        # @return [TwoPartFloat, Exact] the value in the target precision
        # @raise [UnknownPrecisionError] when +to+ is not recognised
        # @raise [ArgumentError] when asked to coerce +:exact+ down to
        #   +:standard+, which would lose precision
        def coerce(value, to:)
          case validate!(to)
          when :exact
            value.is_a?(Exact) ? value : Exact.new(value)
          else
            unless value.is_a?(TwoPartFloat)
              raise ArgumentError,
                "cannot coerce #{value.class} down to :standard without loss"
            end
            value
          end
        end
      end
    end
  end
end
