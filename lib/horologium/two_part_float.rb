# frozen_string_literal: true

module Horologium
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
  #   a = Horologium::TwoPartFloat.new(1.0)
  #   b = Horologium::TwoPartFloat.new(1e-16)
  #   a + b == Horologium::TwoPartFloat.new(1.0, 1e-16)
  #   # => true
  #   1.0 + 1e-16 == 1.0
  #   # => true (the correction is lost)
  # @see https://github.com/liberfa/erfa
  # @see https://www.cs.cmu.edu/~quake/robust.html
  class TwoPartFloat
    # @param high [Float] the high part
    # @param low [Float] the low part
    def initialize(high, low = 0.0)
      @high = high
      @low = low
      freeze
    end

    # Adds another value and keeps the extra precision from both parts.
    #
    # @param other [Horologium::TwoPartFloat] value to add
    # @return [Horologium::TwoPartFloat] the sum
    # @example
    #   Horologium::TwoPartFloat.new(1.5) + Horologium::TwoPartFloat.new(2.25) ==
    #     Horologium::TwoPartFloat.new(3.75)
    #   # => true
    def +(other)
      high_sum, high_error = two_sum(@high, other.high)
      low_sum, low_error = two_sum(@low, other.low)
      result_high, result_low = fast_two_sum(
        high_sum,
        high_error + low_error + low_sum
      )
      self.class.new(result_high, result_low)
    end

    # Subtracts another value and keeps the extra precision from both parts.
    #
    # @param other [Horologium::TwoPartFloat] value to subtract
    # @return [Horologium::TwoPartFloat] the difference
    # @example
    #   Horologium::TwoPartFloat.new(1.5) - Horologium::TwoPartFloat.new(0.25) ==
    #     Horologium::TwoPartFloat.new(1.25)
    #   # => true
    def -(other)
      high_diff, high_error = two_diff(@high, other.high)
      low_diff, low_error = two_diff(@low, other.low)
      result_high, result_low = fast_two_sum(
        high_diff,
        high_error + low_error + low_diff
      )
      self.class.new(result_high, result_low)
    end

    # Two values are equal when their high and low parts are both equal. This
    # compares the stored parts, not the number they add up to.
    #
    # @param other [Object] the object to compare
    # @return [Boolean] true when other is a TwoPartFloat with equal parts
    # @example
    #   obj = Horologium::TwoPartFloat.new(1.0, 0.5)
    #   obj == Horologium::TwoPartFloat.new(1.0, 0.5) # => true
    def ==(other)
      other.is_a?(self.class) && high == other.high && low == other.low
    end

    # The stricter equality used for Hash keys and Sets. It matches when the
    # high and low parts are eql?, so an integer part and a float part differ.
    #
    # @param other [Object] the object to compare
    # @return [Boolean] true when other is a TwoPartFloat with eql? parts
    def eql?(other)
      other.is_a?(self.class) && high.eql?(other.high) && low.eql?(other.low)
    end

    # @return [Integer] a hash built from the two parts
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
    # @return [Horologium::TwoPartFloat] the value with high on the integer
    #   grid and low the fraction, between -0.5 and 0.5
    # @example A fraction stays in the low part
    #   Horologium::TwoPartFloat.normalize(2.0, 0.3) ==
    #     Horologium::TwoPartFloat.new(2.0, 0.3)
    #   # => true
    # @example A low part above one half carries into the high part
    #   Horologium::TwoPartFloat.normalize(2.0, 0.75) ==
    #     Horologium::TwoPartFloat.new(3.0, -0.25)
    #   # => true
    def self.normalize(high, low = 0.0)
      rounded = high.round.to_f
      remainder = high - rounded
      sum, error = two_sum(remainder, low)
      if sum.abs > 0.5
        carry = sum.round.to_f
        carry_sum, carry_error = two_sum(sum - carry, error)
        new_high = rounded + carry
        new_low = carry_sum + carry_error
      else
        new_high = rounded
        new_low = sum + error
      end

      new(new_high, new_low)
    end

    # Adds left and right and also returns the rounding error of the addition.
    # Adding the two results back together gives left + right with no loss.
    # This is the two-sum algorithm, due to Knuth. It works for any two Floats.
    #
    # @api private
    # @param left [Float]
    # @param right [Float]
    # @return [Array(Float, Float)] the sum and its rounding error
    def self.two_sum(left, right)
      sum = left + right
      right_virtual = sum - left
      [sum, (left - (sum - right_virtual)) + (right - right_virtual)]
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
      right_virtual = difference - left
      [
        difference,
        (left - (difference - right_virtual)) - (right + right_virtual)
      ]
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
      [sum, smaller - (sum - larger)]
    end

    protected

    # The two parts. They are protected so the operators can read another
    # value's parts without exposing them publicly.
    #
    # @api private
    # @return [Float]
    attr_reader :high, :low

    private

    def two_sum(left, right)
      self.class.two_sum(left, right)
    end

    def two_diff(left, right)
      self.class.two_diff(left, right)
    end

    def fast_two_sum(larger, smaller)
      self.class.fast_two_sum(larger, smaller)
    end
  end
end
