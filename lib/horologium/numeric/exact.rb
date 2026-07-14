# frozen_string_literal: true

module Horologium
  # The numeric cores the library computes with: {Exact}, which holds a value
  # as an exact Rational, and {TwoPartFloat}, which holds it as a pair of Floats
  # for about twice the precision of one.
  module Numeric
    # A number stored as an exact Rational, with no rounding. Where TwoPartFloat
    # trades a little accuracy for the speed of Float arithmetic, Exact keeps
    # the value exactly, as a ratio of two integers.
    #
    # The value is frozen on creation.
    #
    # @example An exact third, which no Float can hold
    #   Horologium::Numeric::Exact.new(Rational(1, 3)) ==
    #     Horologium::Numeric::Exact.new(Rational(1, 3))
    #   # => true
    # @see Horologium::Numeric::TwoPartFloat
    class Exact
      # @param value [Integer, Float, Rational] the number to store, converted
      #   to an exact Rational with to_r. A Float is stored as its exact binary
      #   value, which is not always the decimal you typed, so pass a Rational
      #   when you mean an exact decimal. Exact records the value it is given
      #   faithfully; it does not recover precision already lost before
      #   construction.
      def initialize(value)
        @value = value.to_r
        freeze
      end

      # Adds another exact value. Both are Rationals, so the sum is exact.
      #
      # @param other [Horologium::Numeric::Exact] value to add
      # @return [Horologium::Numeric::Exact] the sum
      # @example
      #   Horologium::Numeric::Exact.new(Rational(1, 3)) +
      #     Horologium::Numeric::Exact.new(Rational(1, 6)) ==
      #     Horologium::Numeric::Exact.new(Rational(1, 2))
      #   # => true
      def +(other)
        self.class.new(value + other.value)
      end

      # Subtracts another exact value. Both are Rationals, so the difference is
      # exact.
      #
      # @param other [Horologium::Numeric::Exact] value to subtract
      # @return [Horologium::Numeric::Exact] the difference
      # @example
      #   Horologium::Numeric::Exact.new(Rational(1, 2)) -
      #     Horologium::Numeric::Exact.new(Rational(1, 6)) ==
      #     Horologium::Numeric::Exact.new(Rational(1, 3))
      #   # => true
      def -(other)
        self.class.new(value - other.value)
      end

      # Multiplies by a plain number. The number becomes an exact Rational, so
      # the product stays exact.
      #
      # @param scalar [Integer, Float, Rational] the number to multiply by
      # @return [Horologium::Numeric::Exact] the product
      # @raise [ArgumentError] when given anything but a plain number, such
      #   as another exact value
      # @example
      #   Horologium::Numeric::Exact.new(Rational(1, 3)) * 6 ==
      #     Horologium::Numeric::Exact.new(2)
      #   # => true
      def *(scalar) # rubocop:disable Naming/BinaryOperatorParameterName
        self.class.new(value * scalar_rational(scalar))
      end

      # Divides by a plain number. The number becomes an exact Rational, so
      # the quotient stays exact.
      #
      # @param scalar [Integer, Float, Rational] the number to divide by
      # @return [Horologium::Numeric::Exact] the quotient
      # @raise [ArgumentError] when given anything but a plain number, such
      #   as another exact value
      # @example
      #   Horologium::Numeric::Exact.new(2) / 6 ==
      #     Horologium::Numeric::Exact.new(Rational(1, 3))
      #   # => true
      def /(scalar) # rubocop:disable Naming/BinaryOperatorParameterName
        self.class.new(value / scalar_rational(scalar))
      end

      # Two values are equal when their Rationals are equal.
      #
      # @param other [Object] the object to compare
      # @return [Boolean] true when other is an Exact with an equal value
      # @example
      #   Horologium::Numeric::Exact.new(1) == Horologium::Numeric::Exact.new(1)
      #   # => true
      def ==(other)
        other.is_a?(self.class) && value == other.value
      end

      # The stricter equality used for Hash keys and Sets. It matches when the
      # Rationals are eql?, which for Rational is the same test as ==.
      #
      # @param other [Object] the object to compare
      # @return [Boolean] true when other is an Exact with an eql? value
      def eql?(other)
        other.is_a?(self.class) && value.eql?(other.value)
      end

      # @return [Integer] a hash built from the Rational, so equal values share
      #   a hash and can be used as Hash keys
      def hash
        value.hash
      end

      # The stored value as a Rational.
      #
      # @return [Rational]
      # @example
      #   Horologium::Numeric::Exact.new(Rational(1, 3)).to_r == Rational(1, 3)
      #   # => true
      def to_r
        value
      end

      # The value as a single Float. A Float cannot hold what a Rational
      # holds, so the extra precision is dropped here. Do it at the end, once
      # the arithmetic is done.
      #
      # @return [Float] the nearest Float to the value
      # @example
      #   Horologium::Numeric::Exact.new(Rational(1, 3)).to_f
      #   # => 0.3333333333333333
      def to_f
        value.to_f
      end

      protected

      # The stored Rational. It is protected so == and eql? can read another
      # Exact value's Rational without exposing it publicly.
      #
      # @api private
      # @return [Rational]
      attr_reader :value

      private

      # A plain number, as a Rational. An exact value is not a scalar, and
      # passing one where a number belongs is a mistake, so it is refused.
      #
      # @param scalar [Integer, Float, Rational] the number to check
      # @return [Rational] the number as a Rational
      # @raise [ArgumentError] when it is not a plain number
      def scalar_rational(scalar)
        case scalar
        when Integer, Float, Rational
          scalar.to_r
        else
          raise ArgumentError,
            "an Exact multiplies and divides by a plain number, " \
            "got a #{scalar.class}"
        end
      end
    end
  end
end
