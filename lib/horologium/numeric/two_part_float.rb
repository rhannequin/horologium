# frozen_string_literal: true

module Horologium
  module Numeric
    # A number stored as the sum of two Floats, a high part and a low part.
    # The low part carries the bits that do not fit in the high part, so the
    # pair holds about twice the precision of a single Float.
    #
    # The value is frozen on creation, and every operation returns a new one.
    #
    # The representation and the way it is normalized follow the convention
    # used by ERFA (a relicensed version of the SOFA library). The error-free
    # transformations come from Shewchuk's work on robust floating-point
    # arithmetic, and go back to Knuth and Dekker.
    #
    # @example Keeping precision a single Float would lose
    #   a = Horologium::Numeric::TwoPartFloat.new(1.0)
    #   b = Horologium::Numeric::TwoPartFloat.new(1e-16)
    #   a + b == Horologium::Numeric::TwoPartFloat.new(1.0, 1e-16)
    #   # => true
    #   1.0 + 1e-16 == 1.0
    #   # => true (the correction is lost)
    # @see https://github.com/liberfa/erfa
    # @see https://www.cs.cmu.edu/~quake/robust.html
    class TwoPartFloat
      # The constant Dekker's split multiplies by, 2**27 + 1. It cuts a
      # Float's 53-bit mantissa in two, so the halves multiply with no
      # rounding.
      SPLIT_FACTOR = 134_217_729.0

      # @param high [Float] the high part
      # @param low [Float] the low part
      def initialize(high, low = 0.0)
        @high = high
        @low = low
        freeze
      end

      # @param other [Horologium::Numeric::TwoPartFloat]
      # @return [Horologium::Numeric::TwoPartFloat]
      def +(other)
        high_sum = @high + other.high
        low_sum = @low + other.low
        tail = TwoPartFloat.sum_error(@high, other.high, high_sum) +
          TwoPartFloat.sum_error(@low, other.low, low_sum) + low_sum
        result_high = high_sum + tail

        self.class.new(
          result_high,
          TwoPartFloat.fast_sum_error(high_sum, tail, result_high)
        )
      end

      # @param other [Horologium::Numeric::TwoPartFloat]
      # @return [Horologium::Numeric::TwoPartFloat]
      def -(other)
        high_diff = @high - other.high
        low_diff = @low - other.low
        tail = TwoPartFloat.difference_error(@high, other.high, high_diff) +
          TwoPartFloat.difference_error(@low, other.low, low_diff) + low_diff
        result_high = high_diff + tail

        self.class.new(
          result_high,
          TwoPartFloat.fast_sum_error(high_diff, tail, result_high)
        )
      end

      # @param scalar [Integer, Float, Rational]
      # @return [Horologium::Numeric::TwoPartFloat]
      # @raise [ArgumentError] when given anything but a plain number
      def *(scalar) # rubocop:disable Naming/BinaryOperatorParameterName
        factor = scalar_float(scalar)
        high = @high + @low
        low = TwoPartFloat.sum_error(@high, @low, high)
        product = high * factor
        tail = TwoPartFloat.product_error(high, factor, product) + low * factor
        result_high = product + tail

        self.class.new(
          result_high,
          TwoPartFloat.fast_sum_error(product, tail, result_high)
        )
      end

      # @param scalar [Integer, Float, Rational]
      # @return [Horologium::Numeric::TwoPartFloat]
      # @raise [ArgumentError] when given anything but a plain number
      # @raise [ZeroDivisionError] when dividing by zero
      def /(scalar) # rubocop:disable Naming/BinaryOperatorParameterName
        divisor = scalar_float(scalar)
        raise ZeroDivisionError, "divided by 0" if divisor.zero?

        high = @high + @low
        low = TwoPartFloat.sum_error(@high, @low, high)
        quotient = high / divisor
        product = quotient * divisor
        remainder = high - product
        correction = (
          TwoPartFloat.difference_error(high, product, remainder) + low
        ) - TwoPartFloat.product_error(quotient, divisor, product)
        next_quotient = (remainder + correction) / divisor
        result_high = quotient + next_quotient

        self.class.new(
          result_high,
          TwoPartFloat.fast_sum_error(quotient, next_quotient, result_high)
        )
      end

      # The two parts added with no loss. Each Float is an exact rational, so
      # their sum is exact and keeps the low part. A zero low part has nothing
      # to add, and that is the common case: it is how a value built from a
      # single number is held.
      #
      # @return [Rational]
      def to_r
        return high.to_r if low.zero?

        high.to_r + low.to_r
      end

      # The value as a single Float. One Float cannot hold what two hold, so
      # the extra precision the split carries is dropped here. Do it at the
      # end, once the arithmetic is done.
      #
      # @return [Float]
      def to_f
        high + low
      end

      # Whether the two parts add up to nothing. A pair that cancels, such as
      # a high part of 1.0 and a low part of -1.0, reads as zero.
      #
      # @return [Boolean]
      def zero?
        to_f.zero?
      end

      # @return [Boolean]
      def negative?
        to_f.negative?
      end

      # @return [Boolean]
      def positive?
        to_f.positive?
      end

      # Compares the stored parts, not the number they add up to.
      #
      # @param other [Object]
      # @return [Boolean]
      def ==(other)
        other.is_a?(self.class) && high == other.high && low == other.low
      end

      # @param other [Object]
      # @return [Boolean]
      def eql?(other)
        other.is_a?(self.class) && high.eql?(other.high) && low.eql?(other.low)
      end

      # @return [Integer]
      def hash
        [high, low].hash
      end

      # Rebuilds a (high, low) pair into a canonical form: high is the nearest
      # integer and low is the leftover fraction, between -0.5 and 0.5. Use it
      # when the parts do not already follow that form, for example when low is
      # larger than one half.
      #
      # @param high [Float] the high part
      # @param low [Float] the low part
      # @return [Horologium::Numeric::TwoPartFloat] the value with high on the
      #   integer grid and low the fraction, between -0.5 and 0.5
      # @example A low part above one half carries into the high part
      #   Horologium::Numeric::TwoPartFloat.normalize(2.0, 0.75) ==
      #     Horologium::Numeric::TwoPartFloat.new(3.0, -0.25)
      #   # => true
      def self.normalize(high, low = 0.0)
        rounded = high.round.to_f
        remainder = high - rounded
        sum = remainder + low
        error = sum_error(remainder, low, sum)
        if sum.abs > 0.5
          carry = sum.round.to_f
          carry_sum = (sum - carry) + error
          new_high = rounded + carry
          new_low = carry_sum + sum_error(sum - carry, error, carry_sum)
        else
          new_high = rounded
          new_low = sum + error
        end

        new(new_high, new_low)
      end

      # Builds a two-part float from a single real number, keeping the
      # precision a single Float would lose. The high part is the nearest
      # Float and the low part carries the remainder.
      #
      # @param value [Numeric] the number to represent
      # @return [Horologium::Numeric::TwoPartFloat]
      # @example An integer past a Float's reach keeps its last digit
      #   Horologium::Numeric::TwoPartFloat.from_real(2**53 + 1).to_r ==
      #     2**53 + 1
      #   # => true
      def self.from_real(value)
        high = value.to_f
        new(high, (value.to_r - high.to_r).to_f)
      end

      # Adds left and right and also returns the rounding error of the addition.
      # Adding the two results back together gives left + right with no loss.
      # This is the two-sum algorithm, due to Knuth. It works for any two
      # Floats.
      #
      # @api private
      # @param left [Float]
      # @param right [Float]
      # @return [Array(Float, Float)] the sum and its rounding error
      def self.two_sum(left, right)
        sum = left + right

        [sum, sum_error(left, right, sum)]
      end

      # The rounding error of an addition whose sum you already have. It is
      # {two_sum} without the pair, for the arithmetic below, where boxing a
      # pair of Floats costs more than the addition it carries.
      #
      # @api private
      # @param left [Float]
      # @param right [Float]
      # @param sum [Float] the sum of left and right
      # @return [Float] what the addition rounded away
      def self.sum_error(left, right, sum)
        right_virtual = sum - left

        (left - (sum - right_virtual)) + (right - right_virtual)
      end

      # Subtracts right from left and also returns the rounding error. Adding
      # the two results back together gives left - right with no loss. It is the
      # two-difference companion of two_sum and works for any two Floats.
      #
      # @api private
      # @param left [Float]
      # @param right [Float]
      # @return [Array(Float, Float)] the difference and its rounding error
      def self.two_diff(left, right)
        difference = left - right

        [difference, difference_error(left, right, difference)]
      end

      # The rounding error of a subtraction whose difference you already have,
      # the {two_diff} companion of {sum_error}.
      #
      # @api private
      # @param left [Float]
      # @param right [Float]
      # @param difference [Float] left minus right
      # @return [Float] what the subtraction rounded away
      def self.difference_error(left, right, difference)
        right_virtual = difference - left

        (left - (difference - right_virtual)) - (right + right_virtual)
      end

      # Dekker's fast-two-sum, a quicker version of two_sum. It is only correct
      # when larger is at least as large as smaller in magnitude, so use it when
      # you already know which part is bigger.
      #
      # @api private
      # @param larger [Float] the part with the larger magnitude
      # @param smaller [Float] the part with the smaller magnitude
      # @return [Array(Float, Float)] the sum and its rounding error
      def self.fast_two_sum(larger, smaller)
        sum = larger + smaller

        [sum, fast_sum_error(larger, smaller, sum)]
      end

      # The rounding error of a {fast_two_sum} whose sum you already have.
      #
      # @api private
      # @param larger [Float] the part with the larger magnitude
      # @param smaller [Float] the part with the smaller magnitude
      # @param sum [Float] the sum of the two
      # @return [Float] what the addition rounded away
      def self.fast_sum_error(larger, smaller, sum)
        smaller - (sum - larger)
      end

      # Multiplies left and right and also returns the rounding error of the
      # product. Adding the two results back together gives left * right with
      # no loss. Ruby has no fused multiply-add, so each operand is split in
      # two and the partial products stay exact.
      #
      # @api private
      # @param left [Float]
      # @param right [Float]
      # @return [Array(Float, Float)] the product and its rounding error
      def self.two_product(left, right)
        product = left * right

        [product, product_error(left, right, product)]
      end

      # The rounding error of a multiplication whose product you already have,
      # the {two_product} companion of {sum_error}.
      #
      # @api private
      # @param left [Float]
      # @param right [Float]
      # @param product [Float] left times right
      # @return [Float] what the multiplication rounded away
      def self.product_error(left, right, product)
        left_high = split_high(left)
        left_low = left - left_high
        right_high = split_high(right)
        right_low = right - right_high

        ((left_high * right_high - product) +
          left_high * right_low +
          left_low * right_high) +
          left_low * right_low
      end

      # Splits a Float into a high and a low half that add back to the value
      # and each multiply with no rounding. It is Dekker's method, cutting the
      # mantissa in two with {SPLIT_FACTOR}.
      #
      # @api private
      # @param value [Float]
      # @return [Array(Float, Float)] the high half and the low half
      def self.split(value)
        high = split_high(value)

        [high, value - high]
      end

      # The high half of a split mantissa, which is {split} without the pair.
      #
      # @api private
      # @param value [Float]
      # @return [Float] the high half
      def self.split_high(value)
        scaled = SPLIT_FACTOR * value

        scaled - (scaled - value)
      end

      # The two parts. Read them to pass the value to a foreign kernel that
      # takes a day and a fraction of a day, such as an ERFA binding or a
      # Chebyshev ephemeris segment. To add them together, use {#to_f}.
      #
      # @return [Float]
      attr_reader :high, :low

      private

      # A plain number, as a Float. Multiplying or dividing by another
      # two-part value would collapse it to one Float and lose the low part,
      # so it is refused rather than silently rounded.
      #
      # @param scalar [Integer, Float, Rational] the number to check
      # @return [Float] the number as a Float
      # @raise [ArgumentError] when it is not a plain number
      def scalar_float(scalar)
        case scalar
        when Integer, Float, Rational
          scalar.to_f
        else
          raise ArgumentError,
            "a TwoPartFloat multiplies and divides by a plain number, " \
            "got a #{scalar.class}"
        end
      end
    end
  end
end
