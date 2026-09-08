# frozen_string_literal: true

module Horologium
  # A single point on the timeline, independent of any scale. It is stored as a
  # TAI Julian Date, in days, at a fixed precision.
  #
  # @example Shift an instant, then measure back to it
  #   instant = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
  #   later = instant + Horologium::Duration.seconds(3600)
  #   (later - instant) == Horologium::Duration.seconds(3600)
  #   # => true
  class Instant
    include PreciseValue

    class << self
      # Builds an instant from a Julian Date read in a scale.
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
      # @raise [InvalidValueError] when the Julian Date is none of the
      #   shapes above
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @example The same instant, given in TT and read back in TAI
      #   instant = Horologium::Instant.from_julian_date(
      #     "2443144.5003725",
      #     scale: :tt,
      #     precision: :exact
      #   )
      #   instant.as(:julian_date, scale: :tai) # => 2443144.5
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

      # Builds an instant from a Modified Julian Date read in a scale.
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
      # @raise [InvalidValueError] when it is none of the shapes
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
      # scale.
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
      # @raise [InvalidValueError] when a field is not a number the library
      #   reads
      # @raise [UnknownPrecisionError] when the precision is not recognised
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

      # Builds an instant from a TAI calendar date and time.
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

      # Builds an instant from a TT calendar date and time.
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

      # Builds an instant from a TDB calendar date and time.
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

      # Builds an instant from a TCG calendar date and time.
      #
      # @return [Horologium::Instant]
      # @raise [InvalidCivilTimeError] when the fields are not a real date and
      #   time
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @see from_civil
      def from_tcg(
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
          :tcg,
          precision
        )
      end

      # Builds an instant from a TCB calendar date and time.
      #
      # @return [Horologium::Instant]
      # @raise [InvalidCivilTimeError] when the fields are not a real date and
      #   time
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @see from_civil
      def from_tcb(
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
          :tcb,
          precision
        )
      end

      # Builds an instant from a GPS calendar date and time.
      #
      # @return [Horologium::Instant]
      # @raise [InvalidCivilTimeError] when the fields are not a real date and
      #   time
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @see from_civil
      def from_gps(
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
          :gps,
          precision
        )
      end

      # Builds an instant from a UTC calendar date and time.
      #
      # @return [Horologium::Instant]
      # @raise [OutOfRangeError] before 1961-01-01
      # @raise [InvalidCivilTimeError] when the fields are not a real date and
      #   time, such as second 60 on a day with no leap second
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @see from_civil
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

      # Builds an instant from a UT1 calendar date and time.
      #
      # @return [Horologium::Instant]
      # @raise [InvalidCivilTimeError] when the fields are not a real date and
      #   time
      # @raise [OutOfDataRangeError] where delta T is not published
      # @raise [UnknownPrecisionError] when the precision is not recognised
      # @see from_civil
      def from_ut1(
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
          :ut1,
          precision
        )
      end

      # Builds an instant from an ISO 8601 date and time read in a scale.
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
      # @raise [InvalidValueError] when the value is not a String
      # @raise [UnknownPrecisionError] when the precision is not recognised
      def from_iso8601(value, scale:, precision: Horologium.current_precision)
        from_representation(
          Representations::Iso8601,
          value,
          nil,
          scale,
          precision
        )
      end

      # Builds an instant from a Ruby +Time+.
      #
      # @param time [Time] the moment to read
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Instant]
      # A +Time+ cannot hold a leap second. A timestamp that carried a
      # second 60 lost it upstream; read that one with {from_utc}.
      #
      # @raise [InvalidValueError] when it is not a Time
      # @raise [UnknownPrecisionError] when the precision is not recognised
      def from_time(time, precision: Horologium.current_precision)
        unless time.is_a?(Time)
          raise InvalidValueError,
            "a Time is expected, got a #{time.class}; a Date or a DateTime " \
            "converts with #to_time"
        end

        utc = time.getutc
        from_utc(
          utc.year, utc.month, utc.day, utc.hour, utc.min,
          utc.sec + Rational(utc.subsec),
          precision: precision
        )
      end

      # The instant the system clock reads now, through {from_time}.
      #
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Instant]
      # @raise [UnknownPrecisionError] when the precision is not recognised
      def now(precision: Horologium.current_precision)
        from_time(Time.now, precision: precision)
      end

      # Builds an instant from Unix time, the seconds since 1970-01-01 00:00:00
      # UTC. Unix time doesn't count leap seconds: every day in it is 86,400
      # seconds, so it is a way of writing a UTC date rather than a count of
      # elapsed SI seconds, and POSIX is what defines the reading.
      #
      # @param seconds [Integer, Float, Rational] the seconds since the epoch
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Instant]
      # Unix time has no leap seconds, so it names a UTC date rather than
      # counting elapsed seconds. Adding the same number to {Epochs::UNIX}
      # gives an earlier instant, by every leap second since 1970.
      #
      # @raise [InvalidValueError] when the count is not a finite number
      # @raise [UnknownPrecisionError] when the precision is not recognised
      def from_unix(seconds, precision: Horologium.current_precision)
        from_time(
          Time.at(Numeric::Precision.number!(seconds), in: "UTC"),
          precision: precision
        )
      end

      # Builds an instant a duration after another one. That is what an epoch
      # and an elapsed time say together.
      #
      # @param origin [Horologium::Instant] the instant to count from
      # @param elapsed [Horologium::Duration] the time since it
      # @return [Horologium::Instant]
      # @raise [DimensionalError] when the arguments are not an instant and a
      #   duration
      def from_offset(origin, elapsed)
        unless origin.is_a?(self)
          raise DimensionalError,
            "an offset counts from an Instant, got a #{origin.class}"
        end

        origin + elapsed
      end

      private

      # A civil time from the fields a constructor was called with.
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
      # scale.
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

    # Subtracts a duration to get an earlier instant, or another instant to get
    # the Duration between them.
    #
    # @param other [Horologium::Duration, Horologium::Instant]
    # @return [Horologium::Instant, Horologium::Duration]
    # @raise [DimensionalError] when given anything else
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

    # The instant read in a time scale.
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

    # The instant in a representation, read in a scale.
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

    # Whether two instants fall within a tolerance of each other.
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

    # The stored TAI Julian Date. Inspecting an instant needs no scale and no
    # date the calendar conversion has to reach.
    #
    # @return [String]
    def inspect
      format("#<%s %s TAI JD (%s)>", self.class, value.to_f, precision)
    end

    private

    # The duration's seconds counted in days, at the given precision.
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
