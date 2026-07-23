# frozen_string_literal: true

module Horologium
  module Representations
    # A calendar date and a time of day, in the scale it was read in. It is
    # what {Civil} renders, and what {Instant.from_civil} is given.
    #
    # The fields are the ones a clock and a calendar show. The date is in the
    # proleptic Gregorian calendar, with astronomical year numbering: year 0
    # exists, and 1 BC is year 0, 2 BC is year -1. The seconds are split in
    # two, a whole {#second} and the {#second_fraction} under it, because the
    # whole second is the field a leap second lands in and the fraction is the
    # field precision lands in.
    #
    # A CivilTime is frozen and holds no scale of its own: 12:00 in TAI and
    # 12:00 in TT are different instants, so two civil times are compared as
    # sets of fields, and only comparing the instants they came from compares
    # points on the timeline. That is why it is not Comparable.
    #
    # It does not check that its fields make a real date. {Civil} does, when it
    # reads one, because which days exist is calendar knowledge and which
    # seconds exist is scale knowledge, and neither belongs to a set of fields.
    #
    # @example
    #   instant = Horologium::Instant.from_civil(2025, 5, 1, 12, scale: :tt)
    #   civil = instant.as(:civil, scale: :tt)
    #
    #   civil.year   # => 2025
    #   civil.hour   # => 12
    class CivilTime
      # The year, in astronomical numbering.
      #
      # @return [Integer]
      attr_reader :year

      # The month, from 1 to 12.
      #
      # @return [Integer]
      attr_reader :month

      # The day of the month, from 1.
      #
      # @return [Integer]
      attr_reader :day

      # The hour, from 0 to 23.
      #
      # @return [Integer]
      attr_reader :hour

      # The minute, from 0 to 59.
      #
      # @return [Integer]
      attr_reader :minute

      # The whole second, from 0 to 59, and 60 on a day that holds a leap
      # second.
      #
      # @return [Integer]
      attr_reader :second

      # The part of a second under {#second}, from 0 up to but not including
      # 1. Its type is the one asked for when the reading was rendered: a Float
      # by default, a Rational under +as: :rational+, which is the shape that
      # keeps the whole value.
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
      # compared by the exact value it holds. A Float fraction and a Rational
      # one are equal only when they are the same number, so a reading rendered
      # as a Float is not equal to the same reading rendered as a Rational
      # unless the Float happened to hold it exactly. This is how {Instant}
      # compares too, and it is the library declining to call a rounded value
      # the value it was rounded from.
      #
      # @param other [Object] the object to compare
      # @return [Boolean]
      def ==(other)
        other.is_a?(CivilTime) && fields == other.fields
      end

      # The same comparison as {#==}, so a civil time works as a Hash key.
      #
      # @param other [Object] the object to compare
      # @return [Boolean]
      def eql?(other)
        self == other
      end

      # @return [Integer] a hash matching {#eql?}
      def hash
        [self.class, fields].hash
      end

      # The fields, for reading in a console. It is a debugging shape, not a
      # format to parse: it names no scale, and a civil time without its scale
      # does not say which instant it is.
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
          (second_fraction.zero? ? "" : second_fraction.to_f.to_s[1..])
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
    end
  end
end
