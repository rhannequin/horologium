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

      protected

      # The stored Rational. It is protected so == and eql? can read another
      # Exact value's Rational without exposing it publicly.
      #
      # @api private
      # @return [Rational]
      attr_reader :value
    end
  end
end
