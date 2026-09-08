# frozen_string_literal: true

module Horologium
  module Scales
    # Coordinated Universal Time, the civil scale of clocks and calendars. It
    # keeps close to the Earth's rotation by holding a leap second now and then,
    # so a UTC day is usually 86,400 SI seconds but 86,401 on a day that gains
    # one.
    #
    # Source:
    #  Title: IERS Bulletin C, and the pre-1972 drift formulae
    #  Notes: TAI - UTC from 1961, integer leap seconds from 1972
    #  Implementation: ERFA eraDat, eraUtctai and eraTaiutc
    class UTC < Base
      # The Julian Day Number of 1961-01-01, the first day the published
      # TAI - UTC series covers. A reading on an earlier day is refused.
      FIRST_DAY = 2_437_301

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

      # The magnitude a Julian Date has to stay under for the Floats around it
      # to be less than a day apart. Over it a guess read off the Floats could
      # land further out than the search walks back, so {guess_day} works the
      # day out exactly instead.
      #
      # @api private
      GUESSABLE = 2**52
      private_constant :GUESSABLE

      class << self
        # A TAI Julian Date, read in UTC. It finds the UTC day the instant falls
        # in, then takes the fraction through that day back off the leap second
        # spread and the drift, leaving a plain time of day.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UTC, in days
        # @raise [OutOfRangeError] before 1961-01-01
        # @raise [OutOfDataRangeError] past the data horizon in strict mode
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def from_reference(value, precision)
          day = guess_day(value)

          MAX_STEPS.times do
            break if day < FIRST_DAY

            dat0 = tai_utc_at(day)
            midnight = midnight_tai(day, precision, dat0)
            if before_midnight?(value, midnight)
              day -= 1
              next
            end

            next_dat0 = tai_utc_at(day + 1)
            next_midnight = midnight_tai(day + 1, precision, next_dat0)
            unless before_midnight?(value, next_midnight)
              day += 1
              next
            end

            enforce_horizon(day)
            return Numeric::Precision.add(
              Numeric::Precision.build(day - HALF, precision),
              unstretch(value, midnight, day_scale(day, dat0, next_dat0))
            )
          end

          refuse
        end

        # A UTC Julian Date, read back in TAI. It takes the fraction through the
        # UTC day, spreads it over the day's real length with the leap second
        # and the drift included, and adds it to the TAI of that day's 0h.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UTC, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @raise [OutOfRangeError] before 1961-01-01
        # @raise [OutOfDataRangeError] past the data horizon in strict mode
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def to_reference(value, precision)
          day = (value.to_r + HALF).floor
          refuse unless day >= FIRST_DAY
          enforce_horizon(day)

          dat0 = tai_utc_at(day)
          scaled = day_fraction(value, day, precision) *
            day_scale(day, dat0, tai_utc_at(day + 1))

          Numeric::Precision.add(
            Numeric::Precision.build(day - HALF, precision),
            Numeric::Precision.add(
              scaled,
              Numeric::Precision.build(dat0, precision) /
                Duration::SECONDS_PER_DAY
            )
          )
        end

        # The seconds the civil clock counts in a UTC day: 86,400, and 86,401 on
        # a day that holds a whole leap second, where the last minute reaches
        # second 60.
        #
        # @param day_number [Integer] the Julian Day Number of the day
        # @return [Integer] the civil seconds in that day
        # @raise [OutOfRangeError] before 1961-01-01
        def seconds_in_day(day_number)
          refuse unless day_number >= FIRST_DAY

          Duration::SECONDS_PER_DAY + whole_leap_seconds(
            tai_utc_at(day_number),
            tai_utc_at(day_number + 1)
          )
        end

        # The SI seconds a UTC day spans: 86,400, one more on a day that holds a
        # leap second, and a fraction more through the pre-1972 drift.
        #
        # @param day_number [Integer] the Julian Day Number of the day
        # @return [Integer, Rational] the SI seconds in that day
        # @raise [OutOfRangeError] before 1961-01-01
        def si_seconds_in_day(day_number)
          refuse unless day_number >= FIRST_DAY

          day_scale(
            day_number,
            tai_utc_at(day_number),
            tai_utc_at(day_number + 1)
          ) * Duration::SECONDS_PER_DAY
        end

        # UTC writes +Z+, since a zero offset is a real thing there.
        #
        # @return [String]
        def zone_designator
          "Z"
        end

        # How well founded a UTC reading is.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UTC, in days
        # @return [Symbol] +:measured+ or +:extrapolated+
        def provenance(value)
          past_horizon?((value.to_r + HALF).floor) ? :extrapolated : :measured
        end

        private

        # Refuses a date past the data horizon when the configuration asks for
        # it.
        #
        # @param day_number [Integer] the Julian Day Number of the UTC day
        # @return [void]
        # @raise [OutOfDataRangeError] in strict mode, past the horizon
        def enforce_horizon(day_number)
          limit = horizon_date
          return if limit.nil? || day_number <= limit.jd
          return unless strict?

          raise OutOfDataRangeError,
            "the leap second data expires #{limit}, and this moment is after " \
            "it, where a leap second announced since would not be known. " \
            "leap_second_horizon is :raise, so it is refused; set it to " \
            ":extrapolate to read it with the last known offset."
        end

        # Whether a day is past the point the leap second data vouches for.
        #
        # @param day_number [Integer] the Julian Day Number of the UTC day
        # @return [Boolean]
        def past_horizon?(day_number)
          limit = horizon_date
          !limit.nil? && day_number > limit.jd
        end

        # The date the leap second data vouches through, from the source when it
        # can say, or nil.
        #
        # @return [Date, nil]
        # @raise [ConfigurationError] when the source's +expires_on+ is neither
        #   a date nor nil
        def horizon_date
          source = Horologium.configuration.leap_second_source
          return nil unless source.respond_to?(:expires_on)

          date = source.expires_on
          return nil if date.nil?
          return date if date.respond_to?(:jd)

          raise ConfigurationError,
            "a leap second source's expires_on must be a Date or nil, " \
            "got #{date.inspect}"
        end

        # @return [Boolean]
        def strict?
          Horologium.configuration.leap_second_horizon == :raise
        end

        # The fraction through the UTC day a Julian Date falls, from 0 at its 0h
        # to just under 1 at the next.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UTC, in days
        # @param day [Integer] the Julian Day Number of the day it falls in
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the fraction through the day
        def day_fraction(value, day, precision)
          Numeric::Precision.subtract(
            value,
            Numeric::Precision.build(day - HALF, precision)
          )
        end

        # The fraction through the UTC day a TAI Julian Date falls, taken back
        # off the day's length.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param midnight [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the TAI Julian Date of the day's 0h
        # @param scale [Rational] the factor the day's length stretches by
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the fraction through the day
        def unstretch(value, midnight, scale)
          Numeric::Precision.subtract(value, midnight) / scale
        end

        # Whether a TAI instant falls before a UTC day's 0h.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param midnight [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the TAI Julian Date of the day's 0h
        # @return [Boolean]
        def before_midnight?(value, midnight)
          Numeric::Precision.subtract(value, midnight).negative?
        end

        # The UTC day a TAI Julian Date is likely to fall in, read off the
        # Floats.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @return [Integer] the Julian Day Number to start the search at
        def guess_day(value)
          days = value.to_f
          return (value.to_r + HALF).floor unless days.abs < GUESSABLE

          (days + 0.5).floor
        end

        # The TAI Julian Date of a UTC day's 0h.
        #
        # @param day [Integer] the Julian Day Number of the day
        # @param precision [Symbol] +:standard+ or +:exact+
        # @param dat0 [Integer, Rational] TAI - UTC at the day's 0h
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the TAI Julian Date of its 0h
        def midnight_tai(day, precision, dat0)
          Numeric::Precision.add(
            Numeric::Precision.build(day - HALF, precision),
            Numeric::Precision.build(dat0, precision) /
              Duration::SECONDS_PER_DAY
          )
        end

        # How much longer a UTC day is than 86,400 SI seconds, as the factor the
        # day fraction is multiplied by.
        #
        # @param day [Integer] the Julian Day Number of the day
        # @param dat0 [Integer, Rational] TAI - UTC at the day's 0h
        # @param next_dat0 [Integer, Rational] TAI - UTC at the next day's 0h
        # @return [Rational] the factor, 1 on an ordinary day
        def day_scale(day, dat0, next_dat0)
          seconds = Duration::SECONDS_PER_DAY
          leap = whole_leap_seconds(dat0, next_dat0)
          rate = drift_rate(day, dat0)

          (seconds + leap) * (seconds + rate) / (seconds * seconds)
        end

        # The drift in TAI - UTC across a day, its change from 0h to 0h were
        # there no jump at the boundary: zero from 1972 on, a fraction of a
        # second before then.
        #
        # @param day [Integer] the Julian Day Number of the day
        # @param dat0 [Integer, Rational] TAI - UTC at the day's 0h
        # @return [Rational] the drift across the day, in seconds
        def drift_rate(day, dat0)
          2 * (tai_utc_at(day + HALF).to_r - dat0.to_r)
        end

        # The whole leap seconds a UTC day holds, the whole-second part of the
        # step in TAI - UTC across it: one on a leap day, none on an ordinary
        # one, and none in the drift era, where the step is a fraction the civil
        # clock doesn't show.
        #
        # @param dat0 [Integer, Rational] TAI - UTC at the day's 0h
        # @param next_dat0 [Integer, Rational] TAI - UTC at the next day's 0h
        # @return [Integer] the whole leap seconds, 0 or 1
        def whole_leap_seconds(dat0, next_dat0)
          (next_dat0.to_r - dat0.to_r).to_i
        end

        # TAI - UTC at a point in UTC, from the configured source.
        #
        # @param day_number [Integer, Rational] the Julian Day Number of the
        #   day, or a point through it
        # @return [Integer, Rational] TAI - UTC in seconds
        def tai_utc_at(day_number)
          Horologium.configuration.leap_second_source.tai_utc_at(day_number)
        end

        # Refuses a moment before UTC runs, naming the scales that reach it.
        #
        # @raise [OutOfRangeError] always
        def refuse
          raise OutOfRangeError,
            "UTC runs from 1961-01-01 on. This moment is before it, so it " \
            "has no UTC label. Read it in a continuous scale instead, such " \
            "as from_tt, which has no lower bound."
        end
      end
    end
  end
end
