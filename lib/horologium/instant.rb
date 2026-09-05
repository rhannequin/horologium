# frozen_string_literal: true

module Horologium
  # A single point on the timeline, independent of any scale. It is stored as
  # a TAI Julian Date, in days, at a fixed precision.
  #
  # An Instant is built from a Julian Date read in a scale, and can be read
  # back in any scale the library knows: a scale is what turns a number into a
  # point, and the point itself has none.
  #
  # An Instant is frozen. Its precision is set when it is built, from the
  # precision in effect unless you pass one. At +:standard+ the Julian Date is
  # a {Numeric::TwoPartFloat}, at +:exact+ a {Numeric::Exact}.
  #
  # You can add or subtract a Duration, and subtract another Instant to get
  # the Duration between them. Adding two instants raises {DimensionalError}.
  # Mixing a +:standard+ and an +:exact+ operand gives an +:exact+ result.
  #
  # @example Shift an instant, then measure back to it
  #   instant = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
  #   later = instant + Horologium::Duration.seconds(3600)
  #   (later - instant) == Horologium::Duration.seconds(3600)
  #   # => true
  class Instant
    include PreciseValue

    class << self
      # Builds an instant from a Julian Date read in a scale. The Julian Date
      # is read back in TAI, the scale an instant is stored in, so a point
      # given in one scale can be read in another.
      #
      # The lossless shapes come first: a String and a Rational say the Julian
      # Date exactly, and a high and a low Float say it to about twice what one
      # Float holds. A single Float is the lossy one, worth about 40
      # microseconds at a modern date, and the loss is already in the literal
      # by the time the library sees it. See
      # {Representations::JulianDate.parse}.
      #
      # @param value [String, Rational, Integer, Float] the Julian Date, in
      #   days, or its high part when a low part follows
      # @param low [Float, Integer, nil] the low part of the Julian Date, in
      #   days
      # @param scale [Symbol] the scale the Julian Date is read in, such as
      #   +:tt+
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Instant]
      # @raise [UnknownScaleError] when no scale is registered under that name
      # @raise [ParseError] when a String does not spell a Julian Date
      # @raise [ArgumentError] when the Julian Date is none of the shapes above
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @example The same instant, given in TT and read back in TAI
      #   instant = Horologium::Instant.from_julian_date(
      #     "2443144.5003725",
      #     scale: :tt,
      #     precision: :exact
      #   )
      #   instant.as(:julian_date, scale: :tai) # => 2443144.5
      # @example A Julian Date given as a high and a low part
      #   Horologium::Instant.from_julian_date(
      #     2_456_463.0,
      #     0.052272,
      #     scale: :tt
      #   )
      def from_julian_date(
        value,
        low = nil,
        scale:,
        precision: Horologium.current_precision
      )
        from_representation(
          Representations::JulianDate,
          value,
          low,
          scale,
          precision
        )
      end

      # Builds an instant from a Modified Julian Date read in a scale. It is
      # the Julian Date counted from a later origin, and it is given in the
      # same shapes as {from_julian_date}.
      #
      # @param value [String, Rational, Integer, Float] the Modified Julian
      #   Date, in days, or its high part when a low part follows
      # @param low [Float, Integer, nil] the low part, in days
      # @param scale [Symbol] the scale it is read in, such as +:tt+
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Instant]
      # @raise [UnknownScaleError] when no scale is registered under that name
      # @raise [ParseError] when a String does not spell a Modified Julian Date
      # @raise [ArgumentError] when it is none of the shapes
      #   {from_julian_date} takes
      # @raise [UnknownPrecisionError] when the precision is not recognised
      def from_modified_julian_date(
        value,
        low = nil,
        scale:,
        precision: Horologium.current_precision
      )
        from_representation(
          Representations::ModifiedJulianDate,
          value,
          low,
          scale,
          precision
        )
      end

      # Builds an instant from a calendar date and a time of day read in a
      # scale. Nothing is lost: the date becomes a whole number of days and the
      # time of day an exact fraction of one, so this is an exact way to build
      # an instant where a Julian Date given as a single Float is not.
      #
      # The second may carry a fraction under it. Give that fraction as a
      # Rational to say it exactly; a Float second says only what a Float
      # holds, which at this magnitude is far more than a clock reads.
      #
      # A {Representations::CivilTime} may be passed on its own, which is what
      # a reading taken with +as(:civil)+ returns, so a civil time reads back
      # into the instant it came from.
      #
      # @param year [Integer, Horologium::Representations::CivilTime] the year,
      #   or a civil time holding every field
      # @param month [Integer, nil] the month, from 1 to 12
      # @param day [Integer, nil] the day of the month
      # @param hour [Integer] the hour, from 0 to 23
      # @param minute [Integer] the minute, from 0 to 59
      # @param second [Integer, Float, Rational] the second, whole or with a
      #   fraction under it
      # @param scale [Symbol] the scale it is read in, such as +:tt+
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Instant]
      # @raise [UnknownScaleError] when no scale is registered under that name
      # @raise [InvalidCivilTimeError] when the fields are not a real date and
      #   time
      # @raise [ArgumentError] when a field is not a number the library reads
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @example A fractional second, said exactly
      #   Horologium::Instant.from_civil(
      #     2025, 5, 1, 12, 0, Rational(1, 4), scale: :tt
      #   )
      # @example A civil time, read back into the instant it came from
      #   civil = instant.as(:civil, scale: :tt, as: :rational)
      #   Horologium::Instant.from_civil(civil, scale: :tt) == instant # => true
      def from_civil(
        year,
        month = nil,
        day = nil,
        hour = 0,
        minute = 0,
        second = 0,
        scale:,
        precision: Horologium.current_precision
      )
        from_representation(
          Representations::Civil,
          civil_time(year, month, day, hour, minute, second),
          nil,
          scale,
          precision
        )
      end

      # Builds an instant from a TAI calendar date and time. It is
      # {from_civil} read in TAI, the continuous scale the library stores
      # instants in.
      #
      # The fields are {from_civil}'s, and a {Representations::CivilTime}
      # may be passed on its own.
      #
      # @return [Horologium::Instant]
      # @raise [InvalidCivilTimeError] when the fields are not a real date and
      #   time
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @see from_civil
      def from_tai(
        year,
        month = nil,
        day = nil,
        hour = 0,
        minute = 0,
        second = 0,
        precision: Horologium.current_precision
      )
        from_representation(
          Representations::Civil,
          civil_time(year, month, day, hour, minute, second),
          nil,
          :tai,
          precision
        )
      end

      # Builds an instant from a TT calendar date and time. It is {from_civil}
      # read in TT, the scale the theories of the solar system motion are
      # written in.
      #
      # The fields are {from_civil}'s, and a {Representations::CivilTime}
      # may be passed on its own.
      #
      # @return [Horologium::Instant]
      # @raise [InvalidCivilTimeError] when the fields are not a real date and
      #   time
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @see from_civil
      def from_tt(
        year,
        month = nil,
        day = nil,
        hour = 0,
        minute = 0,
        second = 0,
        precision: Horologium.current_precision
      )
        from_representation(
          Representations::Civil,
          civil_time(year, month, day, hour, minute, second),
          nil,
          :tt,
          precision
        )
      end

      # Builds an instant from a TDB calendar date and time. It is
      # {from_civil} read in TDB, the scale the planetary ephemerides are
      # written in.
      #
      # The fields are {from_civil}'s, and a {Representations::CivilTime}
      # may be passed on its own.
      #
      # @return [Horologium::Instant]
      # @raise [InvalidCivilTimeError] when the fields are not a real date and
      #   time
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @see from_civil
      def from_tdb(
        year,
        month = nil,
        day = nil,
        hour = 0,
        minute = 0,
        second = 0,
        precision: Horologium.current_precision
      )
        from_representation(
          Representations::Civil,
          civil_time(year, month, day, hour, minute, second),
          nil,
          :tdb,
          precision
        )
      end

      # Builds an instant from a UTC calendar date and time. It is
      # {from_civil} read in UTC, the scale of civil clocks, so a leap second
      # is a legal reading: the second may be 60 on a day that holds one.
      #
      # UTC runs from 1961-01-01, whole leap seconds from 1972 and the earlier
      # rate-adjustment drift before that. An earlier date raises
      # {OutOfRangeError} and names the continuous constructors, which reach
      # any date.
      #
      # The fields are {from_civil}'s.
      #
      # @return [Horologium::Instant]
      # @raise [OutOfRangeError] before 1961-01-01
      # @raise [InvalidCivilTimeError] when the fields are not a real date and
      #   time, such as second 60 on a day with no leap second
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @see from_civil
      # @example The 2016 leap second, a moment that existed
      #   Horologium::Instant.from_utc(2016, 12, 31, 23, 59, 60)
      def from_utc(
        year,
        month = nil,
        day = nil,
        hour = 0,
        minute = 0,
        second = 0,
        precision: Horologium.current_precision
      )
        from_representation(
          Representations::Civil,
          civil_time(year, month, day, hour, minute, second),
          nil,
          :utc,
          precision
        )
      end

      # Builds an instant from an ISO 8601 date and time read in a scale. The
      # string is read in the strict subset {Representations::Iso8601} parses:
      # a calendar date, an optional time of day after a +T+ down to a fraction
      # of a second, and an optional +Z+ or numeric offset. A date on its own
      # is midnight in the scale.
      #
      # The string names no scale of its own, so +scale+ says which one it is
      # read in. A numeric offset is subtracted as plain arithmetic, not a time
      # zone: it consults no zone data, and +Z+ is a zero offset.
      #
      # @param value [String] the date and time, in extended ISO 8601
      # @param scale [Symbol] the scale it is read in, such as +:tt+
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Instant]
      # @raise [UnknownScaleError] when no scale is registered under that name
      # @raise [ParseError] when the string is not in the subset the parser
      #   reads
      # @raise [InvalidCivilTimeError] when the date and time do not exist
      # @raise [ArgumentError] when the value is not a String
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @example A numeric offset, subtracted to reach the scale
      #   Horologium::Instant.from_iso8601(
      #     "2025-05-01T13:00:00+01:00",
      #     scale: :tt
      #   )
      def from_iso8601(value, scale:, precision: Horologium.current_precision)
        from_representation(
          Representations::Iso8601,
          value,
          nil,
          scale,
          precision
        )
      end

      private

      # A civil time from the fields a constructor was called with. A
      # {Representations::CivilTime} is passed straight through, which is what
      # a reading taken with +as(:civil)+ returns; anything else is a set of
      # calendar fields to assemble.
      #
      # @param year [Integer, Horologium::Representations::CivilTime]
      # @param month [Integer, nil]
      # @param day [Integer, nil]
      # @param hour [Integer]
      # @param minute [Integer]
      # @param second [Integer, Float, Rational]
      # @return [Horologium::Representations::CivilTime]
      def civil_time(year, month, day, hour, minute, second)
        return year if year.is_a?(Representations::CivilTime)

        Representations::Civil.from_fields(
          year,
          month,
          day,
          hour,
          minute,
          second
        )
      end

      # Builds an instant from a value given in a representation and read in a
      # scale. The representation says what the number means, the scale reads
      # it back in TAI, and the instant holds it from there.
      #
      # The scale is resolved once and passed to the representation as well as
      # used for the conversion, because a representation may need it to read
      # the value: a civil time in UTC has to ask the scale how long the day is
      # before it can place the seconds in it.
      #
      # @param representation [Class] the representation the value is given in
      # @param value [Object] the value, in that representation
      # @param low [Float, Integer, nil] its low part, when it has one
      # @param name [Symbol] the scale it is read in
      # @param precision [Symbol] +:standard+ or +:exact+
      # @return [Horologium::Instant]
      # @raise [UnknownScaleError] when no scale is registered under that name
      def from_representation(representation, value, low, name, precision)
        scale = Horologium.configuration.scale(name)
        in_scale = representation.parse(value, low, scale, precision)

        new(scale.to_reference(in_scale, precision), precision)
      end
    end

    # Adds a duration and returns a later instant.
    #
    # @param duration [Horologium::Duration] the amount to move forward
    # @return [Horologium::Instant]
    # @raise [DimensionalError] when given anything but a Duration
    def +(duration) # rubocop:disable Naming/BinaryOperatorParameterName
      unless duration.is_a?(Duration)
        raise DimensionalError,
          "cannot add a #{duration.class} to an Instant; " \
          "only a Duration shifts an Instant"
      end

      precision = Numeric::Precision.resolve(self.precision, duration.precision)
      days = seconds_to_days(duration, precision)
      self.class.new(Numeric::Precision.add(value, days), precision)
    end

    # Subtracts a duration to get an earlier instant, or another instant to
    # get the Duration between them.
    #
    # @param other [Horologium::Duration, Horologium::Instant]
    # @return [Horologium::Instant, Horologium::Duration]
    # @raise [DimensionalError] when given anything else
    # @example The Duration between two instants
    #   a = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
    #   b = Horologium::Instant.from_julian_date(2_460_001.5, scale: :tai)
    #   b - a == Horologium::Duration.days(1) # => true
    def -(other)
      case other
      when Duration
        precision = Numeric::Precision.resolve(self.precision, other.precision)
        days = seconds_to_days(other, precision)
        self.class.new(
          Numeric::Precision.subtract(value, days),
          precision
        )
      when Instant
        precision = Numeric::Precision.resolve(self.precision, other.precision)
        gap = Numeric::Precision.subtract(value, other.value)
        Duration.new(gap * Duration::SECONDS_PER_DAY, precision)
      else
        raise DimensionalError,
          "cannot subtract a #{other.class} from an Instant; " \
          "subtract a Duration or another Instant"
      end
    end

    # The instant read in a time scale. An instant has no scale of its own, so
    # the scale is chosen here. Take the representation from the reading it
    # returns.
    #
    # @param scale [Symbol] the name of a registered scale, such as +:tt+
    # @return [Horologium::ScaleReading]
    # @raise [UnknownScaleError] when no scale is registered under that name
    # @raise [OutOfRangeError] when the scale does not reach the instant, such
    #   as UTC before 1972
    # @raise [OutOfDataRangeError] when UTC is past the leap second data
    #   horizon and +leap_second_horizon+ is +:raise+
    def to(scale)
      time_scale = Horologium.configuration.scale(scale)
      reading = time_scale.from_reference(value, precision)

      ScaleReading.new(scale, reading, precision, time_scale)
    end

    # The instant in a representation, read in a scale. This is the shorthand
    # for +to(scale).as(representation)+.
    #
    # @param representation [Symbol] the representation, such as +:julian_date+
    # @param scale [Symbol] the name of a registered scale, such as +:tt+
    # @param as [Symbol] the type to come out as
    # @return [Object] the instant, in that representation
    # @raise [UnknownScaleError] when no scale is registered under that name
    # @raise [UnknownRepresentationError] when the representation is not one
    #   the library has
    def as(representation, scale:, as: :float)
      to(scale).as(representation, as: as)
    end

    # Whether two instants fall within a tolerance of each other. Use this
    # rather than +==+ in scientific code.
    #
    # @param other [Horologium::Instant] the instant to compare with
    # @param tolerance [Horologium::Duration] the largest gap counted as equal
    # @return [Boolean]
    def equal_within?(other, tolerance)
      unless other.is_a?(Instant)
        raise DimensionalError,
          "cannot compare an Instant with a #{other.class}"
      end
      unless tolerance.is_a?(Duration)
        raise DimensionalError,
          "a tolerance must be a Duration, got a #{tolerance.class}"
      end

      (self - other).abs <= tolerance
    end

    # The stored TAI Julian Date, so inspecting an instant needs no scale and
    # no date the calendar conversion has to reach.
    #
    # @return [String]
    def inspect
      format("#<%s %s TAI JD (%s)>", self.class, value.to_f, precision)
    end

    private

    # The duration's seconds counted in days, at the given precision. A Julian
    # Date counts days, so a duration is scaled before it is added.
    #
    # @param duration [Horologium::Duration]
    # @param precision [Symbol]
    # @return [Horologium::Numeric::TwoPartFloat, Horologium::Numeric::Exact]
    def seconds_to_days(duration, precision)
      Numeric::Precision.coerce(duration.value, to: precision) /
        Duration::SECONDS_PER_DAY
    end
  end
end
