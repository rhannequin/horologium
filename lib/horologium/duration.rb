# frozen_string_literal: true

module Horologium
  # An amount of time in SI seconds, with no date and no scale attached.
  # +Duration.days(1)+ is always 86,400 SI seconds. Because of leap seconds a
  # civil day can be a second longer or shorter, so a Duration and a calendar
  # day are different things.
  #
  # A Duration is frozen. Its precision is set when it is built, from the
  # precision in effect unless you pass one. At +:standard+ it holds the
  # seconds as a {Numeric::TwoPartFloat}, at +:exact+ as a {Numeric::Exact}.
  #
  # Two durations add and subtract to give another duration, and one negates.
  # Mixing a +:standard+ and an +:exact+ operand gives an +:exact+ result.
  # Adding an Instant to a Duration raises {DimensionalError}; it is
  # {Instant#+} that shifts a point by a span.
  #
  # A duration reads back in a unit with {#in_seconds}, {#in_days},
  # {#in_julian_years} and {#in_julian_centuries}. They come out as a Float at
  # +:standard+ and a Rational at +:exact+.
  #
  # @example A day is a fixed number of SI seconds
  #   Horologium::Duration.days(1) == Horologium::Duration.seconds(86_400)
  #   # => true
  class Duration
    include PreciseValue

    # The number of SI seconds in a minute.
    SECONDS_PER_MINUTE = 60

    # The number of SI seconds in an hour.
    SECONDS_PER_HOUR = 3_600

    # The number of SI seconds in a day.
    SECONDS_PER_DAY = 86_400

    # The number of SI seconds in a Julian year of 365.25 days.
    SECONDS_PER_JULIAN_YEAR = 31_557_600

    # The number of SI seconds in a Julian century of 36,525 days.
    SECONDS_PER_JULIAN_CENTURY = 3_155_760_000

    # The number of nanoseconds in a second.
    NANOSECONDS_PER_SECOND = 1_000_000_000

    class << self
      # A duration of +count+ SI seconds.
      #
      # @param count [Numeric] the number of seconds
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @example
      #   Horologium::Duration.seconds(3600)
      def seconds(count, precision: Horologium.current_precision)
        from_seconds(count, precision)
      end

      # A duration of +count+ minutes.
      #
      # @param count [Numeric] the number of minutes
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @example
      #   Horologium::Duration.minutes(90)
      def minutes(count, precision: Horologium.current_precision)
        from_seconds(count * SECONDS_PER_MINUTE, precision)
      end

      # A duration of +count+ hours.
      #
      # @param count [Numeric] the number of hours
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @example
      #   Horologium::Duration.hours(6)
      def hours(count, precision: Horologium.current_precision)
        from_seconds(count * SECONDS_PER_HOUR, precision)
      end

      # A duration of +count+ days, each of {SECONDS_PER_DAY} SI seconds. This
      # counts time and is not tied to the calendar.
      #
      # @param count [Numeric] the number of days
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @example
      #   Horologium::Duration.days(1) == Horologium::Duration.seconds(86_400)
      #   # => true
      def days(count, precision: Horologium.current_precision)
        from_seconds(count * SECONDS_PER_DAY, precision)
      end

      # A duration of +count+ Julian years, each of exactly 365.25 days. It is
      # the astronomical constant, and a calendar year holds 365 or 366 days,
      # so shifting an instant by a Julian year lands a few hours away from
      # the same date next year.
      #
      # @param count [Numeric] the number of Julian years
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @example
      #   Horologium::Duration.julian_years(1) ==
      #     Horologium::Duration.days(365.25) # => true
      def julian_years(count, precision: Horologium.current_precision)
        from_seconds(count * SECONDS_PER_JULIAN_YEAR, precision)
      end

      # A duration of +count+ Julian centuries, each of a hundred Julian
      # years, or 36,525 days. It is the unit the astronomical series count
      # their time in.
      #
      # @param count [Numeric] the number of Julian centuries
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @example
      #   Horologium::Duration.julian_centuries(0.25)
      def julian_centuries(count, precision: Horologium.current_precision)
        from_seconds(count * SECONDS_PER_JULIAN_CENTURY, precision)
      end

      # A duration of +count+ nanoseconds.
      #
      # @param count [Numeric] the number of nanoseconds
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @example
      #   Horologium::Duration.nanoseconds(1)
      def nanoseconds(count, precision: Horologium.current_precision)
        from_seconds(Rational(count) / NANOSECONDS_PER_SECOND, precision)
      end

      # A duration of no time at all.
      #
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @example
      #   Horologium::Duration.zero.zero? # => true
      def zero(precision: Horologium.current_precision)
        from_seconds(0, precision)
      end

      private

      # Builds a duration of +seconds+ SI seconds at the given precision. At
      # +:exact+ the seconds stay a Rational; at +:standard+ they become a
      # two-part float. Unit scaling happens on the plain input, before this.
      #
      # @param seconds [Numeric] the number of SI seconds
      # @param precision [Symbol] the precision to build
      # @return [Horologium::Duration]
      def from_seconds(seconds, precision)
        new(Numeric::Precision.build(seconds, precision), precision)
      end
    end

    # @param other [Horologium::Duration]
    # @return [Horologium::Duration]
    # @raise [DimensionalError] when given anything but a Duration
    def +(other)
      unless other.is_a?(Duration)
        raise DimensionalError,
          "cannot add a #{other.class} to a Duration; " \
          "only a Duration combines with a Duration"
      end

      precision = Numeric::Precision.resolve(self.precision, other.precision)

      self.class.new(
        Numeric::Precision.add(value, other.value),
        precision
      )
    end

    # Negative when the other is the longer of the two.
    #
    # @param other [Horologium::Duration]
    # @return [Horologium::Duration]
    # @raise [DimensionalError] when given anything but a Duration
    def -(other)
      unless other.is_a?(Duration)
        raise DimensionalError,
          "cannot subtract a #{other.class} from a Duration; " \
          "only a Duration combines with a Duration"
      end

      precision = Numeric::Precision.resolve(self.precision, other.precision)

      self.class.new(
        Numeric::Precision.subtract(value, other.value),
        precision
      )
    end

    # The same length, the other way round.
    #
    # @return [Horologium::Duration]
    def -@
      self.class.new(value * -1, precision)
    end

    # The same length, never negative.
    #
    # @return [Horologium::Duration]
    def abs
      negative? ? -self : self
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

    # The duration in SI seconds.
    #
    # @return [Float, Rational] a Float at +:standard+, a Rational at
    #   +:exact+
    # @example
    #   Horologium::Duration.days(1).in_seconds # => 86400.0
    def in_seconds
      in_unit(1)
    end

    # The duration in days of {SECONDS_PER_DAY} SI seconds each.
    #
    # @return [Float, Rational] a Float at +:standard+, a Rational at
    #   +:exact+
    # @example
    #   Horologium::Duration.hours(12).in_days # => 0.5
    def in_days
      in_unit(SECONDS_PER_DAY)
    end

    # The duration in Julian years of 365.25 days each.
    #
    # @return [Float, Rational] a Float at +:standard+, a Rational at
    #   +:exact+
    def in_julian_years
      in_unit(SECONDS_PER_JULIAN_YEAR)
    end

    # The duration in Julian centuries of 36,525 days each. It is the time
    # argument the astronomical series are written for.
    #
    # @return [Float, Rational] a Float at +:standard+, a Rational at
    #   +:exact+
    # @example
    #   Horologium::Duration.days(36_525).in_julian_centuries # => 1.0
    def in_julian_centuries
      in_unit(SECONDS_PER_JULIAN_CENTURY)
    end

    # The duration in SI seconds, exactly.
    #
    # @return [Rational]
    def to_r
      value.to_r
    end

    # The duration in SI seconds. A Float has about 15 digits, so a long
    # duration loses its small end here; use {#to_r} for the whole of it.
    #
    # @return [Float]
    def to_f
      value.to_f
    end

    # @return [String]
    def inspect
      format("#<%s %s s (%s)>", self.class, to_f, precision)
    end

    private

    # The duration counted in a unit. The division happens in the precision
    # the duration is held in, so the digits survive it.
    #
    # @param seconds_per_unit [Integer] the SI seconds one unit holds
    # @return [Float, Rational] a Float at +:standard+, a Rational at
    #   +:exact+
    def in_unit(seconds_per_unit)
      return value.to_r / seconds_per_unit if precision == :exact

      (value / seconds_per_unit).to_f
    end
  end
end
