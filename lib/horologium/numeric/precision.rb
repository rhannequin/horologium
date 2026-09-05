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
    # Promotion loses nothing, because a two-part float pair is already an
    # exact Rational. What +:exact+ guarantees is Horologium's own arithmetic.
    # It cannot bring back precision an input already lost when it was built.
    #
    # A scale registered with {Horologium::Configuration#register_scale} builds
    # and combines its values here, so this module is public API.
    module Precision
      # The recognised precisions.
      NAMES = %i[standard exact].freeze

      class << self
        # @param precision [Symbol]
        # @return [Symbol] the same precision
        # @raise [UnknownPrecisionError] when it is not one of {NAMES}
        def validate!(precision)
          case precision
          when :standard, :exact
            precision
          else
            raise UnknownPrecisionError.new(precision, NAMES)
          end
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
        # path: the contagion rule never moves an +:exact+ value down to
        # +:standard+, and asking for that raises an error.
        #
        # @param value [TwoPartFloat, Exact] the value to coerce
        # @param to [Symbol] the target precision
        # @return [TwoPartFloat, Exact] the value in the target precision
        # @raise [UnknownPrecisionError] when +to+ is not recognised
        # @raise [ArgumentError] when asked to coerce +:exact+ down to
        #   +:standard+, which would lose precision
        def coerce(value, to:)
          case to
          when :exact
            value.is_a?(Exact) ? value : Exact.new(value)
          when :standard
            unless value.is_a?(TwoPartFloat)
              raise ArgumentError,
                "cannot coerce #{value.class} down to :standard without loss"
            end
            value
          else
            raise UnknownPrecisionError.new(to, NAMES)
          end
        end

        # Builds a value at a precision, from a plain number: an {Exact} for
        # +:exact+, a {TwoPartFloat} for +:standard+.
        #
        # @param value [Integer, Float, Rational] the number to hold
        # @param precision [Symbol] the precision to hold it at
        # @return [TwoPartFloat, Exact] the number at that precision
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def build(value, precision)
          case validate!(precision)
          when :exact
            Exact.new(value)
          else
            TwoPartFloat.from_real(value)
          end
        end

        # Builds a constant at every precision, once, so a conversion that
        # leans on it does not build it again on every call. The result is a
        # frozen Hash keyed by precision, which answers an unrecognised
        # precision with {UnknownPrecisionError} rather than +nil+, so a
        # caller reads it with +[]+ and needs no fetch of its own.
        #
        # @param value [Integer, Float, Rational] the number to hold
        # @return [Hash{Symbol => TwoPartFloat, Exact}] the number at each
        #   precision
        # @example
        #   OFFSETS = Numeric::Precision.build_each(Rational(19, 86_400))
        #   OFFSETS[:exact] # => a Numeric::Exact
        def build_each(value)
          table = Hash.new do |_, precision|
            raise UnknownPrecisionError.new(precision, NAMES)
          end
          NAMES.each { |precision| table[precision] = build(value, precision) }
          table.freeze
        end

        # Adds two values. Two standard values add as two-part floats; if
        # either is exact, both are promoted to exact Rationals first. Build a
        # plain number into a value with {build} before adding it: a bare
        # Float or Rational is refused, because promoting it would quietly
        # move the result to +:exact+.
        #
        # @param left [TwoPartFloat, Exact] one value
        # @param right [TwoPartFloat, Exact] the other value
        # @return [TwoPartFloat, Exact] the sum
        # @raise [ArgumentError] when either side is not a value
        def add(left, right)
          if left.is_a?(TwoPartFloat) && right.is_a?(TwoPartFloat)
            left + right
          elsif left.is_a?(Exact) && right.is_a?(Exact)
            left + right
          else
            promote(left) + promote(right)
          end
        end

        # Subtracts two values, promoting to exact the same way {add} does.
        #
        # @param left [TwoPartFloat, Exact] the value to subtract from
        # @param right [TwoPartFloat, Exact] the value to subtract
        # @return [TwoPartFloat, Exact] the difference
        # @raise [ArgumentError] when either side is not a value
        def subtract(left, right)
          if left.is_a?(TwoPartFloat) && right.is_a?(TwoPartFloat)
            left - right
          elsif left.is_a?(Exact) && right.is_a?(Exact)
            left - right
          else
            promote(left) - promote(right)
          end
        end

        # Orders two values by the number they denote, whatever precision each
        # is held in. Two two-part floats are compared through the difference
        # of their parts, which is where the answer already is.
        #
        # That difference answers only when it is finite and away from zero.
        # Reaching zero says the values are close rather than equal, and parts
        # large enough to overflow can cancel into a NaN, so both cases are
        # settled exactly instead.
        #
        # @param left [TwoPartFloat, Exact] one value
        # @param right [TwoPartFloat, Exact] the other value
        # @return [Integer] -1, 0, or 1
        def compare(left, right)
          if left.is_a?(TwoPartFloat) && right.is_a?(TwoPartFloat)
            difference = (left.high - right.high) + (left.low - right.low)

            return sign_of(difference) if difference.finite? &&
              !difference.zero?
          end

          sign_of(left.to_r - right.to_r)
        end

        # Checks that a value matches a precision: a {TwoPartFloat} for
        # +:standard+, an {Exact} for +:exact+.
        #
        # @param value [TwoPartFloat, Exact] the value to check
        # @param precision [Symbol] the precision it claims
        # @return [TwoPartFloat, Exact] the same value
        # @raise [UnknownPrecisionError] when the precision is not recognised
        # @raise [ArgumentError] when the value does not match the precision
        def validate_value!(value, precision)
          expected = value_type(precision)
          unless value.is_a?(expected)
            raise ArgumentError,
              "a #{precision} value must be a #{expected}, " \
              "got a #{value.class}"
          end

          value
        end

        # The numeric type a value takes at a precision: {Exact} for +:exact+
        # and {TwoPartFloat} for +:standard+.
        #
        # @param precision [Symbol] the precision
        # @return [Class] the type its values take
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def value_type(precision)
          case precision
          when :standard
            TwoPartFloat
          when :exact
            Exact
          else
            raise UnknownPrecisionError.new(precision, NAMES)
          end
        end

        private

        # Where a number sits against zero.
        #
        # @param number [Float, Rational] the number to read
        # @return [Integer] -1 below zero, 0 at it, 1 above it
        def sign_of(number)
          return 0 if number.zero?

          number.negative? ? -1 : 1
        end

        # One side of an operation, as an exact value.
        #
        # @param value [TwoPartFloat, Exact] the value to promote
        # @return [Exact] the value, exactly
        # @raise [ArgumentError] when it is not a value
        def promote(value)
          unless value.is_a?(TwoPartFloat) || value.is_a?(Exact)
            raise ArgumentError,
              "arithmetic takes a TwoPartFloat or an Exact, " \
              "got a #{value.class}; build it with .build first"
          end

          coerce(value, to: :exact)
        end
      end
    end
  end
end
