# frozen_string_literal: true

module Horologium
  module Numeric
    # The precision a value computes with: +:standard+, the fast two-part float
    # ({TwoPartFloat}), or +:exact+, the lossless Rational ({Exact}). This
    # module holds the rules that decide the precision of a result and coerce a
    # value from one precision into another.
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

        # The precision a result takes from its two operands.
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

        # Coerces a numeric value into a precision, losslessly.
        #
        # @param value [TwoPartFloat, Exact] the value to coerce
        # @param to [Symbol] the target precision
        # @return [TwoPartFloat, Exact] the value in the target precision
        # @raise [UnknownPrecisionError] when +to+ is not recognised
        # @raise [InvalidValueError] when asked to coerce +:exact+ down to
        #   +:standard+, which would lose precision
        def coerce(value, to:)
          case to
          when :exact
            value.is_a?(Exact) ? value : Exact.new(value)
          when :standard
            unless value.is_a?(TwoPartFloat)
              raise InvalidValueError,
                "cannot coerce #{value.class} down to :standard without loss"
            end
            value
          else
            raise UnknownPrecisionError.new(to, NAMES)
          end
        end

        # Checks that a value is a number the library can compute with.
        #
        # @param value [Object] the value to check
        # @return [Integer, Float, Rational] the number, unchanged
        # A Float is tried first, since that is what the hot paths hold.
        #
        # @raise [InvalidValueError] when it is not a finite number
        def number!(value)
          case value
          when Float
            return value if value.finite?

            raise InvalidValueError,
              "a number the library computes with is finite, got #{value}"
          when Integer, Rational then value
          else
            raise InvalidValueError,
              "a number is an Integer, a Float, or a Rational, " \
              "got a #{value.class}"
          end
        end

        # Checks that a number survives becoming a Float.
        #
        # @param value [Object] the value to check
        # @return [Float] the number as a Float
        # @raise [InvalidValueError] when it is not a number, or does not fit
        #   a Float
        def finite_float!(value)
          number = number!(value)
          float = out_of_float_range?(number) ? Float::INFINITY : number.to_f
          return float if float.finite? && !(float.zero? && !number.zero?)

          raise InvalidValueError,
            "#{value} does not fit a Float, so it cannot be held at " \
            ":standard; :exact holds it exactly"
        end

        # Builds a value at a precision, from a plain number: an {Exact} for
        # +:exact+, a {TwoPartFloat} for +:standard+.
        #
        # @param value [Integer, Float, Rational] the number to hold
        # @param precision [Symbol] the precision to hold it at
        # @return [TwoPartFloat, Exact] the number at that precision
        # @raise [UnknownPrecisionError] when the precision is not recognised
        # @raise [InvalidValueError] when the value is not a finite number
        def build(value, precision)
          case validate!(precision)
          when :exact
            Exact.new(number!(value))
          else
            TwoPartFloat.from_real(value)
          end
        end

        # Builds a constant at every precision, once, so a conversion that leans
        # on it doesn't build it again on every call.
        #
        # @param value [Integer, Float, Rational] the number to hold
        # @return [Hash{Symbol => TwoPartFloat, Exact}] the number at each
        #   precision
        def build_each(value)
          table = Hash.new do |_, precision|
            raise UnknownPrecisionError.new(precision, NAMES)
          end
          NAMES.each { |precision| table[precision] = build(value, precision) }
          table.freeze
        end

        # Whether an Integer is too large to become a Float.
        #
        # @param number [Integer, Float, Rational] the number to measure
        # @return [Boolean]
        def out_of_float_range?(number)
          number.is_a?(Integer) && number.abs > Float::MAX
        end

        # Adds two values.
        #
        # @param left [TwoPartFloat, Exact] one value
        # @param right [TwoPartFloat, Exact] the other value
        # @return [TwoPartFloat, Exact] the sum
        # @raise [InvalidValueError] when either side is not a value
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
        # @raise [InvalidValueError] when either side is not a value
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
        # is held in.
        #
        # @param left [TwoPartFloat, Exact] one value
        # @param right [TwoPartFloat, Exact] the other value
        # @return [Integer] -1, 0, or 1
        # @raise [InvalidValueError] when either side is not a value
        def compare(left, right)
          value!(left)
          value!(right)

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
        # @raise [InvalidValueError] when the value does not match the precision
        def validate_value!(value, precision)
          expected = value_type(precision)
          unless value.is_a?(expected)
            raise InvalidValueError,
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
        # @raise [InvalidValueError] when it is not a value
        def promote(value)
          coerce(value!(value), to: :exact)
        end

        # One side of an operation, checked to be a value the library holds
        # numbers in rather than a bare number or something else entirely.
        #
        # @param value [Object] the value to check
        # @return [TwoPartFloat, Exact] the same value
        # @raise [InvalidValueError] when it is not one
        def value!(value)
          return value if value.is_a?(TwoPartFloat) || value.is_a?(Exact)

          raise InvalidValueError,
            "arithmetic takes a TwoPartFloat or an Exact, " \
            "got a #{value.class}; build it with .build first"
        end
      end
    end
  end
end
