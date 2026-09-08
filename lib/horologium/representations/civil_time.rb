# frozen_string_literal: true

module Horologium
  module Representations
    # A calendar date and a time of day, in the scale it was read in. It is what
    # {Civil} renders, and what {Instant.from_civil} is given.
    class CivilTime
      # @return [Integer] the year, in astronomical numbering
      attr_reader :year

      # @return [Integer] the month, from 1 to 12
      attr_reader :month

      # @return [Integer] the day of the month, from 1
      attr_reader :day

      # @return [Integer] the hour, from 0 to 23
      attr_reader :hour

      # @return [Integer] the minute, from 0 to 59
      attr_reader :minute

      # @return [Integer] the whole second, from 0 to 59, and 60 on a day
      #   that holds a leap second
      attr_reader :second

      # The part of a second under {#second}, from 0 up to but not including
      # 1. Its type is the one asked for when the reading was rendered: a Float
      # by default, a Rational under +as: :rational+, which keeps the whole
      # value.
      #
      # @return [Float, Rational, Integer]
      attr_reader :second_fraction

      # @param year [Integer] the year, in astronomical numbering
      # @param month [Integer] the month, from 1 to 12
      # @param day [Integer] the day of the month
      # @param hour [Integer] the hour, from 0 to 23
      # @param minute [Integer] the minute, from 0 to 59
      # @param second [Integer] the whole second
      # @param second_fraction [Float, Rational, Integer] the part of a second
      #   under it
      def initialize(
        year,
        month,
        day,
        hour = 0,
        minute = 0,
        second = 0,
        second_fraction = 0
      )
        @year = year
        @month = month
        @day = day
        @hour = hour
        @minute = minute
        @second = second
        @second_fraction = second_fraction
        freeze
      end

      # Two civil times are equal when every field is, the fraction of a second
      # compared by the exact value it holds.
      #
      # @param other [Object] the object to compare
      # @return [Boolean]
      def ==(other)
        other.is_a?(CivilTime) && fields == other.fields
      end

      # @param other [Object]
      # @return [Boolean]
      def eql?(other)
        self == other
      end

      # @return [Integer]
      def hash
        [self.class, fields].hash
      end

      # The fields, for reading in a console.
      #
      # @return [String]
      def inspect
        format(
          "#<%s %04d-%02d-%02d %02d:%02d:%02d%s>",
          self.class,
          year,
          month,
          day,
          hour,
          minute,
          second,
          fraction_digits
        )
      end

      protected

      # The fields, with the fraction of a second as the exact value it holds,
      # so that equal values compare and hash equal whatever type carries them.
      #
      # @return [Array]
      def fields
        [year, month, day, hour, minute, second, second_fraction.to_r]
      end

      private

      # The fraction of a second, as the digits that follow the second, the
      # leading decimal point among them.
      #
      # @return [String]
      def fraction_digits
        return "" if second_fraction.zero?

        mantissa, marker, exponent = second_fraction.to_f.to_s.partition("e")
        return mantissa[1..] || "" if marker.empty?

        digits = mantissa.delete(".").sub(/0+\z/, "")

        ".#{"0" * (-Integer(exponent, 10) - 1)}#{digits}"
      end
    end
  end
end
