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
    # UTC runs from 1961-01-01, the start of the published TAI - UTC series.
    # From 1972 it steps by whole leap seconds. From 1961 to 1972 it was
    # steered by rate adjustments instead: TAI - UTC drifts by a fraction of a
    # second a day, so a UTC second there is fractionally longer than an SI
    # second and the civil clock still counts 86,400 of them a day, with no
    # second 60. {Data::LeapSeconds} reads both regimes. A reading before 1961
    # raises {OutOfRangeError} and names the continuous scales, which reach any
    # date.
    #
    # @example A leap second is read and written as second 60
    #   instant = Horologium::Instant.from_utc(2016, 12, 31, 23, 59, 60)
    #   instant.as(:iso8601, scale: :utc)
    #   # => "2016-12-31T23:59:60.000000000Z"
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

      class << self
        # A TAI Julian Date, read in UTC. It finds the UTC day the instant
        # falls in, then takes the fraction through that day back off the leap
        # second spread and the drift, so it reads as a plain time of day. This
        # inverts {to_reference} in closed form, exactly at +:exact+.
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
          day = (value.to_r + HALF).floor

          MAX_STEPS.times do
            break if day < FIRST_DAY

            if before_midnight?(value, day, precision)
              day -= 1
            elsif !before_midnight?(value, day + 1, precision)
              day += 1
            else
              enforce_horizon(day)
              return Numeric::Precision.add(
                Numeric::Precision.build(day - HALF, precision),
                unstretch(value, day, precision)
              )
            end
          end

          refuse
        end

        # A UTC Julian Date, read back in TAI. It takes the fraction through
        # the UTC day, spreads it over the day's real length with the leap
        # second and the drift included, and adds it to the TAI of that day's
        # 0h. This is the conversion ERFA performs in +eraUtctai+.
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
          scaled = day_fraction(value, day, precision) * day_scale(day, dat0)

          Numeric::Precision.add(
            Numeric::Precision.build(day - HALF, precision),
            Numeric::Precision.add(
              scaled,
              Numeric::Precision.build(dat0, precision) /
                Duration::SECONDS_PER_DAY
            )
          )
        end

        # The seconds the civil clock counts in a UTC day: 86,400, and 86,401
        # on a day that holds a whole leap second, where the last minute reaches
        # second 60. Before 1972 the day is always 86,400 civil seconds; the
        # drift in TAI - UTC there is spread across the day as slightly longer
        # seconds, not shown as an extra one. The conversion to and from TAI
        # uses the SI length instead, which the drift stretches.
        #
        # @param day_number [Integer] the Julian Day Number of the day
        # @return [Integer] the civil seconds in that day
        # @raise [OutOfRangeError] before 1961-01-01
        def seconds_in_day(day_number)
          refuse unless day_number >= FIRST_DAY

          Duration::SECONDS_PER_DAY + whole_leap_seconds(day_number)
        end

        # The SI seconds a UTC day spans: 86,400, one more on a day that holds a
        # leap second, and a fraction more through the pre-1972 drift. It is the
        # length the conversion to TAI stretches the day over, where
        # {seconds_in_day} is the whole count the civil clock shows. A numeric
        # ISO 8601 offset counts against this, so it shifts by SI seconds even
        # on a drift day.
        #
        # @param day_number [Integer] the Julian Day Number of the day
        # @return [Integer, Rational] the SI seconds in that day
        # @raise [OutOfRangeError] before 1961-01-01
        def si_seconds_in_day(day_number)
          refuse unless day_number >= FIRST_DAY

          day_scale(day_number, tai_utc_at(day_number)) *
            Duration::SECONDS_PER_DAY
        end

        # UTC writes +Z+, where a zero offset is a real thing.
        #
        # @return [String]
        def zone_designator
          "Z"
        end

        # How well founded a UTC reading is. +:measured+ up to the date the
        # leap second data vouches for, +:extrapolated+ past it, where the
        # offset is the last known one and a new leap second could overturn
        # it. A source that states no expiry is taken as +:measured+
        # throughout, since there is no horizon to be past.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UTC, in days
        # @return [Symbol] +:measured+ or +:extrapolated+
        def provenance(value)
          past_horizon?((value.to_r + HALF).floor) ? :extrapolated : :measured
        end

        private

        # Refuses a date past the data horizon when the configuration asks for
        # it. In the default mode it does nothing, and the reading is marked
        # +:extrapolated+ instead.
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
        # False when the source states no expiry, so there is no horizon.
        #
        # @param day_number [Integer] the Julian Day Number of the UTC day
        # @return [Boolean]
        def past_horizon?(day_number)
          limit = horizon_date
          !limit.nil? && day_number > limit.jd
        end

        # The date the leap second data vouches through, from the source when
        # it can say, or nil. A source that answers +expires_on+ with anything
        # but a date or nil is refused here, rather than failing obscurely when
        # the date is asked for its Julian Day Number.
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

        # The fraction through the UTC day a Julian Date falls, from 0 at its
        # 0h to just under 1 at the next. It is the part {to_reference} spreads
        # over the day's length and {from_reference} takes back off it.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UTC, in days
        # @param day [Integer] the Julian Day Number of the day it falls in
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the fraction through the day
        def day_fraction(value, day, precision)
          Numeric::Precision.subtract(
            Numeric::Precision.add(
              value,
              Numeric::Precision.build(HALF, precision)
            ),
            Numeric::Precision.build(day, precision)
          )
        end

        # The fraction through the UTC day a TAI Julian Date falls, taken back
        # off the day's length. It inverts what {to_reference} does to the day
        # fraction, so {from_reference} reads a plain time of day.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param day [Integer] the Julian Day Number of the day it falls in
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the fraction through the day
        def unstretch(value, day, precision)
          dat0 = tai_utc_at(day)
          from_midnight = Numeric::Precision.subtract(
            value,
            Numeric::Precision.add(
              Numeric::Precision.build(day - HALF, precision),
              Numeric::Precision.build(dat0, precision) /
                Duration::SECONDS_PER_DAY
            )
          )

          from_midnight / day_scale(day, dat0)
        end

        # Whether a TAI instant falls before a UTC day's 0h. It is told at the
        # instant's own precision, and the subtraction is error-free, so an
        # instant built at a day's 0h is not pushed into the day before it by a
        # rounding crumb, where an exact comparison would read one that is not
        # there. This is what lets the search settle and the first day stand.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param day [Integer] the Julian Day Number of the day
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Boolean]
        def before_midnight?(value, day, precision)
          Numeric::Precision.subtract(
            value,
            midnight_tai(day, precision)
          ).to_r < 0
        end

        # The TAI Julian Date of a UTC day's 0h. A TAI instant reads in the UTC
        # day whose 0h it falls on or after, up to the next, and this rises with
        # the day even across a leap second or a drift step, so the search for
        # that day settles.
        #
        # @param day [Integer] the Julian Day Number of the day
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the TAI Julian Date of its 0h
        def midnight_tai(day, precision)
          Numeric::Precision.add(
            Numeric::Precision.build(day - HALF, precision),
            Numeric::Precision.build(tai_utc_at(day), precision) /
              Duration::SECONDS_PER_DAY
          )
        end

        # How much longer a UTC day is than 86,400 SI seconds, as the factor the
        # day fraction is multiplied by. It carries the whole leap second spread
        # across the day, the same one {seconds_in_day} shows the clock, and
        # before 1972 the fractional drift. A fractional step at a boundary is
        # not spread in: it stays a clean discontinuity there, since the next
        # day's 0h offset already sits past it.
        #
        # @param day [Integer] the Julian Day Number of the day
        # @param dat0 [Integer, Rational] TAI - UTC at the day's 0h
        # @return [Rational] the factor, 1 on an ordinary day
        def day_scale(day, dat0)
          seconds = Duration::SECONDS_PER_DAY
          leap = whole_leap_seconds(day)
          rate = drift_rate(day, dat0)

          (seconds + leap) * (seconds + rate) / (seconds * seconds)
        end

        # The drift in TAI - UTC across a day, its change from 0h to 0h were
        # there no jump at the boundary: zero from 1972 on, a fraction of a
        # second before then. It is read as twice the change over the first half
        # of the day, so a jump at the next 0h does not enter it.
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
        # clock does not show.
        #
        # @param day_number [Integer] the Julian Day Number of the day
        # @return [Integer] the whole leap seconds, 0 or 1
        def whole_leap_seconds(day_number)
          (tai_utc_at(day_number + 1).to_r - tai_utc_at(day_number).to_r).to_i
        end

        # TAI - UTC at a point in UTC, from the configured source. A whole
        # number of seconds from 1972 on, where leap seconds are whole, and a
        # Rational fraction of a second in the drift era from 1961 to 1972. The
        # point is a day's 0h by its Julian Day Number, or part way through a
        # day where a fraction is added, as {drift_rate} reads it at 12h.
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
