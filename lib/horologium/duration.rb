# frozen_string_literal: true

module Horologium
  # An amount of time in SI seconds, with no date and no scale attached.
  # +Duration.days(1)+ is always 86,400 SI seconds.
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

    # The fields below the +T+. A +T+ with none of them after it is not a
    # duration, whatever the day field before it says.
    #
    # @api private
    CLOCK_FIELDS = %i[hours minutes seconds].freeze
    private_constant :CLOCK_FIELDS

    # The subset of ISO 8601 durations {parse} reads. Every field is
    # optional here. {parse} checks that at least one of them is there
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
      def minutes(count, precision: Horologium.current_precision)
        from_seconds(scaled(count, SECONDS_PER_MINUTE), precision)
      end

      # A duration of +count+ hours.
      #
      # @param count [Numeric] the number of hours
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      def hours(count, precision: Horologium.current_precision)
        from_seconds(scaled(count, SECONDS_PER_HOUR), precision)
      end

      # A duration of +count+ days, each of {SECONDS_PER_DAY} SI seconds.
      #
      # @param count [Numeric] the number of days
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      def days(count, precision: Horologium.current_precision)
        from_seconds(scaled(count, SECONDS_PER_DAY), precision)
      end

      # A duration of +count+ Julian years, each of exactly 365.25 days.
      #
      # @param count [Numeric] the number of Julian years
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      def julian_years(count, precision: Horologium.current_precision)
        from_seconds(scaled(count, SECONDS_PER_JULIAN_YEAR), precision)
      end

      # A duration of +count+ Julian centuries, each of a hundred Julian years,
      # or 36,525 days.
      #
      # @param count [Numeric] the number of Julian centuries
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      def julian_centuries(count, precision: Horologium.current_precision)
        from_seconds(scaled(count, SECONDS_PER_JULIAN_CENTURY), precision)
      end

      # A duration of +count+ nanoseconds.
      #
      # @param count [Numeric] the number of nanoseconds
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      def nanoseconds(count, precision: Horologium.current_precision)
        Numeric::Precision.number!(count)

        from_seconds(Rational(count) / NANOSECONDS_PER_SECOND, precision)
      end

      # The mean of some durations, computed in the split rather than by reading
      # each one out as a Float and averaging those.
      #
      # @param durations [Array<Horologium::Duration>] the durations
      # @return [Horologium::Duration]
      # @raise [DimensionalError] when the list is empty, or holds anything
      #   but durations
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

      # A duration read from an ISO 8601 duration string, in the subset that is
      # a quantity of time, not a calendar period.
      #
      # @param value [String] the duration
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @raise [ParseError] when the string is not in the subset
      # @raise [InvalidValueError] at +:standard+, when a field is a number
      #   too large to hold as a Float; +:exact+ holds it
      # @raise [UnknownPrecisionError] when the precision is not recognised
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
      def zero(precision: Horologium.current_precision)
        from_seconds(0, precision)
      end

      private

      # A count of some unit, in seconds.
      #
      # @param count [Numeric] the number of units
      # @param seconds_per_unit [Numeric] the seconds one unit spans
      # @return [Numeric] the count in seconds
      # @raise [InvalidValueError] when the count is not a finite number
      def scaled(count, seconds_per_unit)
        Numeric::Precision.number!(count)

        count * seconds_per_unit
      end

      # Whether a field other than the smallest one present carries a fraction.
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

      # Builds a duration of +seconds+ SI seconds at the given precision.
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

    # A duration scaled by a plain number.
    #
    # @param scalar [Integer, Float, Rational] the number to scale by
    # @return [Horologium::Duration]
    # @raise [InvalidValueError] when it is not a finite number
    def *(scalar) # rubocop:disable Naming/BinaryOperatorParameterName
      self.class.new(value * Numeric::Precision.number!(scalar), precision)
    end

    # A duration divided by a plain number.
    #
    # @param scalar [Integer, Float, Rational] the number to divide by
    # @return [Horologium::Duration]
    # @raise [InvalidValueError] when it is not a finite number
    # @raise [ZeroDivisionError] when dividing by zero
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
    def in_seconds
      in_unit(1)
    end

    # The duration in minutes of {SECONDS_PER_MINUTE} SI seconds each.
    #
    # @return [Float, Rational] a Float at +:standard+, a Rational at
    #   +:exact+
    def in_minutes
      in_unit(SECONDS_PER_MINUTE)
    end

    # The duration in hours of {SECONDS_PER_HOUR} SI seconds each.
    #
    # @return [Float, Rational] a Float at +:standard+, a Rational at
    #   +:exact+
    def in_hours
      in_unit(SECONDS_PER_HOUR)
    end

    # The duration in days of {SECONDS_PER_DAY} SI seconds each.
    #
    # @return [Float, Rational] a Float at +:standard+, a Rational at
    #   +:exact+
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

    # The duration in Julian centuries of 36,525 days each.
    #
    # @return [Float, Rational] a Float at +:standard+, a Rational at
    #   +:exact+
    def in_julian_centuries
      in_unit(SECONDS_PER_JULIAN_CENTURY)
    end

    # The duration in SI seconds, exactly.
    #
    # @return [Rational]
    def to_r
      value.to_r
    end

    # The duration in SI seconds.
    #
    # @return [Float]
    def to_f
      value.to_f
    end

    # The duration as an ISO 8601 string, in the subset {Duration.parse} reads.
    # The fraction is rounded onto the nanosecond grid, so a duration finer
    # than that doesn't read back into itself; {#to_r} is the lossless read.
    #
    # @return [String]
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

    # The duration counted in a unit.
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
