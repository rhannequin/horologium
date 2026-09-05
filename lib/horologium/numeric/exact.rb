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

      # @param other [Horologium::Numeric::Exact]
      # @return [Horologium::Numeric::Exact]
      def +(other)
        self.class.new(value + other.value)
      end

      # @param other [Horologium::Numeric::Exact]
      # @return [Horologium::Numeric::Exact]
      def -(other)
        self.class.new(value - other.value)
      end

      # @param scalar [Integer, Float, Rational]
      # @return [Horologium::Numeric::Exact]
      # @raise [ArgumentError] when given anything but a plain number
      def *(scalar) # rubocop:disable Naming/BinaryOperatorParameterName
        self.class.new(value * scalar_rational(scalar))
      end

      # @param scalar [Integer, Float, Rational]
      # @return [Horologium::Numeric::Exact]
      # @raise [ArgumentError] when given anything but a plain number
      def /(scalar) # rubocop:disable Naming/BinaryOperatorParameterName
        self.class.new(value / scalar_rational(scalar))
      end

      # @return [Boolean]
      def zero?
        value.zero?
      end

      # @return [Boolean]
      def negative?
        value.negative?
      end

      # @return [Boolean]
      def positive?
        value.positive?
      end

      # @param other [Object]
      # @return [Boolean]
      def ==(other)
        other.is_a?(self.class) && value == other.value
      end

      # @param other [Object]
      # @return [Boolean]
      def eql?(other)
        other.is_a?(self.class) && value.eql?(other.value)
      end

      # @return [Integer]
      def hash
        value.hash
      end

      # @return [Rational]
      def to_r
        value
      end

      # The value as a single Float. A Float cannot hold what a Rational
      # holds, so the extra precision is dropped here. Do it at the end, once
      # the arithmetic is done.
      #
      # @return [Float]
      def to_f
        value.to_f
      end

      protected

      # Protected so == and eql? can read another Exact's Rational.
      #
      # @api private
      # @return [Rational]
      attr_reader :value

      private

      # An exact value is not a scalar, and passing one where a number belongs
      # is a mistake, so it is refused.
      #
      # @param scalar [Integer, Float, Rational]
      # @return [Rational]
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
