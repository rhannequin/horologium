# frozen_string_literal: true

module Horologium
  module Scales
    # Coordinated Universal Time, the civil scale of clocks and calendars. It
    # keeps close to the Earth's rotation by holding a leap second now and
    # then, so a UTC day is usually 86,400 SI seconds but 86,401 on a day that
    # gains one. TAI runs without them, so the gap between the two, TAI - UTC,
    # steps up by a second at each.
    #
    # A UTC Julian Date is not uniform time: a day gaining a leap second still
    # spans one unit of it, so its fraction is stretched over 86,401 seconds.
    # This is the convention ERFA uses, and it is why {Representations::Civil}
    # asks the scale how long the day is. The conversion to and from TAI reads
    # the leap seconds from {Data::LeapSeconds}, and does the arithmetic at the
    # instant's precision, so a UTC to TAI round trip is exact at +:exact+ and
    # within a nanosecond at +:standard+.
    #
    # UTC runs from 1972-01-01, where it settled into whole leap seconds.
    # Before then it was steered by rate adjustments, a messier convention this
    # scale does not read; a UTC reading before 1972 raises {OutOfRangeError}
    # and names the continuous scales, which reach any date.
    #
    # @example A leap second is read and written as second 60
    #   instant = Horologium::Instant.from_utc(2016, 12, 31, 23, 59, 60)
    #   instant.as(:iso8601, scale: :utc)
    #   # => "2016-12-31T23:59:60.000000000Z"
    class UTC < Base
      # The Julian Day Number of 1972-01-01, the first day UTC runs in whole
      # leap seconds. A reading on an earlier day is refused.
      FIRST_DAY = 2_441_318

      # Half a day, the gap between a Julian Date, which starts at noon, and
      # the midnight a day starts at.
      #
      # @api private
      HALF = Rational(1, 2)
      private_constant :HALF

      # The refinement takes at most one step, since a guess from the TAI date
      # is at most a day out. Two more are room to spare before a moment is
      # taken as out of range.
      #
      # @api private
      MAX_STEPS = 3
      private_constant :MAX_STEPS

      class << self
        # A TAI Julian Date, read in UTC. It finds the UTC day the instant
        # falls in, then the fraction of that day, stretched over the day's
        # length so a leap second sits inside it.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UTC, in days
        # @raise [OutOfRangeError] before 1972-01-01
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def from_reference(value, precision)
          day = (value.to_r + HALF).floor

          MAX_STEPS.times do
            break if day < FIRST_DAY

            offset = tai_utc_at(day)
            seclen = day_seconds(day, offset)
            midnight = Numeric::Precision.build(day - HALF, precision)
            seconds = elapsed_seconds(value, midnight, offset, precision)

            step = day_step(seconds.to_r, seclen)
            if step.zero?
              return Numeric::Precision.add(midnight, seconds / seclen)
            end

            day += step
          end

          refuse
        end

        # A UTC Julian Date, read back in TAI. It reads the day off the Julian
        # Date, unstretches the fraction into seconds, and adds them to the TAI
        # of that day's 0h.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UTC, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @raise [OutOfRangeError] before 1972-01-01
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def to_reference(value, precision)
          shifted = Numeric::Precision.add(
            value,
            Numeric::Precision.build(HALF, precision)
          )
          day = shifted.to_r.floor
          refuse unless day >= FIRST_DAY

          offset = tai_utc_at(day)
          seclen = day_seconds(day, offset)
          midnight = Numeric::Precision.build(day - HALF, precision)
          fraction = Numeric::Precision.subtract(
            shifted,
            Numeric::Precision.build(day, precision)
          )
          seconds = fraction * seclen

          Numeric::Precision.add(
            midnight,
            Numeric::Precision.add(
              Numeric::Precision.build(offset, precision),
              seconds
            ) / Duration::SECONDS_PER_DAY
          )
        end

        # The SI seconds in a UTC day: 86,400, and 86,401 on a day that holds
        # a leap second, from the step in TAI - UTC across it.
        #
        # @param day_number [Integer] the Julian Day Number of the day
        # @return [Integer] the seconds in that day
        # @raise [OutOfRangeError] before 1972-01-01
        def seconds_in_day(day_number)
          refuse unless day_number >= FIRST_DAY

          day_seconds(day_number, tai_utc_at(day_number))
        end

        # UTC writes the +Z+ designator, where a zero offset is a real thing.
        #
        # @return [String]
        def zone_designator
          "Z"
        end

        private

        # The seconds in a day, from the offset at its 0h and the next.
        #
        # @param day_number [Integer] the Julian Day Number of the day
        # @param offset [Integer, Rational] TAI - UTC at the day's 0h
        # @return [Integer] the seconds in the day
        def day_seconds(day_number, offset)
          Duration::SECONDS_PER_DAY + (tai_utc_at(day_number + 1) - offset)
        end

        # The SI seconds from the day's 0h UTC to the instant, as a value at
        # the given precision.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI
        # @param midnight [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date of the day's 0h UTC
        # @param offset [Integer, Rational] TAI - UTC at that 0h
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the seconds since 0h UTC
        def elapsed_seconds(value, midnight, offset, precision)
          tai_at_0h = Numeric::Precision.add(
            midnight,
            Numeric::Precision.build(offset, precision) / Duration::SECONDS_PER_DAY
          )

          Numeric::Precision.subtract(value, tai_at_0h) *
            Duration::SECONDS_PER_DAY
        end

        # Which way the guessed day is wrong: before its 0h, a day early; past
        # its end, a day late; inside it, right.
        #
        # @param seconds [Rational] the seconds since the guessed day's 0h
        # @param seclen [Integer] the seconds in the guessed day
        # @return [Integer] -1, 0, or 1
        def day_step(seconds, seclen)
          return -1 if seconds < 0
          return 1 if seconds >= seclen

          0
        end

        # TAI - UTC at a day's 0h UTC, from the configured source.
        #
        # @param day_number [Integer] the Julian Day Number of the day
        # @return [Integer, Rational] TAI - UTC in seconds
        def tai_utc_at(day_number)
          Horologium.configuration.leap_second_source.tai_utc_at(day_number)
        end

        # Refuses a moment before UTC runs, naming the scales that reach it.
        #
        # @raise [OutOfRangeError] always
        def refuse
          raise OutOfRangeError,
            "UTC runs from 1972-01-01 on. This moment is before it, so it " \
            "has no UTC label. Read it in a continuous scale instead, such " \
            "as from_civil with scale: :tt, which has no lower bound."
        end
      end
    end
  end
end
