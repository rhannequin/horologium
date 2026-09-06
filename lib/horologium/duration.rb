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
  # A duration also scales by a plain number, with {#*} and {#/}, which is
  # what keeps it usable: a quantity that only combines with its own kind
  # sends a caller back to raw seconds the moment they want half of one.
  # {mean} averages a list of them in the split. Mixing a +:standard+ and an
  # +:exact+ operand gives an +:exact+ result. Adding an Instant to a
  # Duration raises {DimensionalError}; it is {Instant#+} that shifts a point
  # by a span.
  #
  # A duration reads and writes ISO 8601 with {parse} and {#to_iso8601}, in
  # the subset that is a quantity of time rather than a walk through a
  # calendar.
  #
  # A duration reads back in a unit with {#in_seconds}, {#in_minutes},
  # {#in_hours}, {#in_days}, {#in_julian_years} and {#in_julian_centuries}.
  # They come out as a Float at +:standard+ and a Rational at +:exact+.
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

    # The ISO 8601 duration fields the library reads, and the seconds each
    # one counts. Years and months are absent because a duration cannot say
    # how long they are.
    #
    # @api private
    FIELDS = {
      days: SECONDS_PER_DAY,
      hours: SECONDS_PER_HOUR,
      minutes: SECONDS_PER_MINUTE,
      seconds: 1
    }.freeze
    private_constant :FIELDS

    # The fields that sit below the +T+. A +T+ that opens none of them is not
    # a duration, however well formed the day field before it is.
    #
    # @api private
    CLOCK_FIELDS = %i[hours minutes seconds].freeze
    private_constant :CLOCK_FIELDS

    # The subset of ISO 8601 durations {parse} reads. Every field is
    # optional here, so {parse} checks that at least one of them is there
    # rather than leaving a bare +P+ or +PT+ to match.
    #
    # @api private
    PATTERN = /
      \A(?<sign>-)?P
        (?:(?<days>\d+(?:\.\d+)?)D)?
        (?<clock>T
          (?:(?<hours>\d+(?:\.\d+)?)H)?
          (?:(?<minutes>\d+(?:\.\d+)?)M)?
          (?:(?<seconds>\d+(?:\.\d+)?)S)?
        )?
      \z
    /x
    private_constant :PATTERN

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
        from_seconds(scaled(count, SECONDS_PER_MINUTE), precision)
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
        from_seconds(scaled(count, SECONDS_PER_HOUR), precision)
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
        from_seconds(scaled(count, SECONDS_PER_DAY), precision)
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
        from_seconds(scaled(count, SECONDS_PER_JULIAN_YEAR), precision)
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
        from_seconds(scaled(count, SECONDS_PER_JULIAN_CENTURY), precision)
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
        Numeric::Precision.number!(count)

        from_seconds(Rational(count) / NANOSECONDS_PER_SECOND, precision)
      end

      # The mean of some durations, computed in the split rather than by
      # reading each one out as a Float and averaging those. Exactness is
      # contagious, so a mean over any exact duration is exact.
      #
      # @param durations [Array<Horologium::Duration>] the durations
      # @return [Horologium::Duration]
      # @raise [DimensionalError] when the list is empty, or holds anything
      #   but durations
      # @example
      #   Horologium::Duration.mean(
      #     [Horologium::Duration.seconds(1), Horologium::Duration.seconds(3)]
      #   ) == Horologium::Duration.seconds(2)
      #   # => true
      def mean(durations)
        list = Array(durations)

        if list.empty?
          raise DimensionalError, "the mean of no durations is not a duration"
        end

        list.each do |duration|
          next if duration.is_a?(self)

          raise DimensionalError,
            "the mean is of Durations, got a #{duration.class}"
        end

        list.sum(zero(precision: list.first.precision)) / list.length
      end

      # A duration read from an ISO 8601 duration string, in the subset that
      # is a quantity of time rather than a walk through a calendar.
      #
      # +P+ opens it, +T+ opens the part below a day, and the fields are
      # +D+, +H+, +M+ and +S+, each an optional number, the last of which may
      # carry a fraction. A leading +-+ negates the whole of it.
      #
      # Years and months are refused, and weeks with them. A year is 365 days
      # or 366 and a month is anywhere from 28 to 31, so +P1Y+ names a span
      # the calendar resolves and a duration cannot (see §5.4's note on
      # calendar arithmetic). +P1W+ is unambiguous at seven days, but it is
      # not part of the subset either, and +P7D+ says the same thing.
      #
      # @param value [String] the duration
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @raise [ParseError] when the string is not in the subset
      # @raise [InvalidValueError] at +:standard+, when a field is a number
      #   too large to hold as a Float; +:exact+ holds it
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @example
      #   Horologium::Duration.parse("PT4H5M6S").in_seconds # => 14706.0
      def parse(value, precision: Horologium.current_precision)
        match = value.is_a?(String) && PATTERN.match(value)
        refuse(value) unless match

        present = FIELDS.keys.select { |name| match[name] }
        refuse(value) if present.empty?
        refuse(value) if match[:clock] && (present & CLOCK_FIELDS).empty?
        refuse(value) if fraction_above_the_last?(match, present)

        seconds = present.sum { |name| Rational(match[name]) * FIELDS[name] }

        from_seconds(match[:sign] ? -seconds : seconds, precision)
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

      # A count of some unit, in seconds. The count is checked before it is
      # multiplied, so a count that is not a number is refused by the library
      # rather than by Ruby's own arithmetic.
      #
      # @param count [Numeric] the number of units
      # @param seconds_per_unit [Numeric] the seconds one unit spans
      # @return [Numeric] the count in seconds
      # @raise [InvalidValueError] when the count is not a finite number
      def scaled(count, seconds_per_unit)
        Numeric::Precision.number!(count)

        count * seconds_per_unit
      end

      # Whether a field other than the smallest one present carries a
      # fraction. ISO 8601 allows a fraction on the last field only, so
      # +PT1.5H1M+ is malformed: it says an hour and a half and then a
      # minute, which is two ways of dividing the same hour.
      #
      # @param match [MatchData] the parsed fields
      # @param present [Array<Symbol>] the fields that are there, largest
      #   first
      # @return [Boolean]
      def fraction_above_the_last?(match, present)
        present.first(present.length - 1).any? do |name|
          match[name].include?(".")
        end
      end

      # @param value [Object] what could not be read
      # @raise [ParseError] always
      def refuse(value)
        raise ParseError,
          "#{value.inspect} is not an ISO 8601 duration the library reads. " \
          "It reads a quantity of time, such as PT4H5M6S or P3D. Years and " \
          "months are refused because a duration cannot say how long they " \
          "are; weeks are seven days exactly but sit outside the subset all " \
          "the same, and P7D says the same thing"
      end

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

    # A duration scaled by a plain number. Scaling is what keeps a duration
    # usable: a quantity that can only be added to another of its kind sends
    # a caller back to raw seconds the moment they need half of one, and the
    # precision the type exists to protect goes with them.
    #
    # @param scalar [Integer, Float, Rational] the number to scale by
    # @return [Horologium::Duration]
    # @raise [InvalidValueError] when it is not a finite number
    # @example
    #   Horologium::Duration.hours(1) * 1.5 ==
    #     Horologium::Duration.minutes(90)
    #   # => true
    def *(scalar) # rubocop:disable Naming/BinaryOperatorParameterName
      self.class.new(value * Numeric::Precision.number!(scalar), precision)
    end

    # A duration divided by a plain number.
    #
    # @param scalar [Integer, Float, Rational] the number to divide by
    # @return [Horologium::Duration]
    # @raise [InvalidValueError] when it is not a finite number
    # @raise [ZeroDivisionError] when dividing by zero
    # @example
    #   Horologium::Duration.hours(1) / 2 ==
    #     Horologium::Duration.minutes(30)
    #   # => true
    def /(scalar) # rubocop:disable Naming/BinaryOperatorParameterName
      self.class.new(value / Numeric::Precision.number!(scalar), precision)
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

    # The duration in minutes of {SECONDS_PER_MINUTE} SI seconds each.
    #
    # @return [Float, Rational] a Float at +:standard+, a Rational at
    #   +:exact+
    # @example
    #   Horologium::Duration.hours(1).in_minutes # => 60.0
    def in_minutes
      in_unit(SECONDS_PER_MINUTE)
    end

    # The duration in hours of {SECONDS_PER_HOUR} SI seconds each.
    #
    # @return [Float, Rational] a Float at +:standard+, a Rational at
    #   +:exact+
    # @example
    #   Horologium::Duration.days(1).in_hours # => 24.0
    def in_hours
      in_unit(SECONDS_PER_HOUR)
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

    # The duration as an ISO 8601 string, in the subset {Duration.parse}
    # reads. Whole days come out as a day field and the rest below the +T+,
    # zero fields are left out, and the seconds carry a fraction when they
    # have one.
    #
    # **The string holds nanoseconds, and not everything fits.** The fraction
    # is rounded onto the nanosecond grid, the way an instant's ISO 8601 is,
    # so a duration on that grid reads back into itself and one finer than it
    # does not: an exact third of a second writes as +PT0.333333333S+, and a
    # quarter of a nanosecond writes as +PT0S+. A third of a second has no
    # finite decimal form at any resolution, so this is a property of the
    # format rather than of the choice of grid. Use {#to_r} where the whole
    # value has to survive; this is an interchange form, like {#to_f}.
    #
    # @return [String]
    # @example
    #   Horologium::Duration.seconds(14_706).to_iso8601 # => "PT4H5M6S"
    def to_iso8601
      total = (to_r * NANOSECONDS_PER_SECOND).round
      return "PT0S" if total.zero?

      sign = total.negative? ? "-" : ""
      whole, fraction = total.abs.divmod(NANOSECONDS_PER_SECOND)
      days, rest = whole.divmod(SECONDS_PER_DAY)
      hours, rest = rest.divmod(SECONDS_PER_HOUR)
      minutes, seconds = rest.divmod(SECONDS_PER_MINUTE)

      "#{sign}P#{"#{days}D" if days.positive?}" \
        "#{clock_part(hours, minutes, seconds, fraction)}"
    end

    # @return [String]
    def inspect
      format("#<%s %s s (%s)>", self.class, to_f, precision)
    end

    private

    # The part of an ISO 8601 duration below a day, empty when there is none.
    #
    # @param hours [Integer]
    # @param minutes [Integer]
    # @param seconds [Integer] the whole seconds
    # @param fraction [Integer] the nanoseconds under them
    # @return [String]
    def clock_part(hours, minutes, seconds, fraction)
      return "" if [hours, minutes, seconds, fraction].all?(&:zero?)

      written = +"T"
      written << "#{hours}H" if hours.positive?
      written << "#{minutes}M" if minutes.positive?
      return written if seconds.zero? && fraction.zero?

      digits = format("%09d", fraction).sub(/0+\z/, "")
      written << (fraction.zero? ? "#{seconds}S" : "#{seconds}.#{digits}S")
    end

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
