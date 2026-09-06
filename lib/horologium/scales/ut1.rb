# frozen_string_literal: true

module Horologium
  module Scales
    # Universal Time, the scale the actual rotation of the Earth keeps. It is
    # the only scale here that is measured rather than defined: the Earth does
    # not turn at a constant rate, so UT1 - TT cannot be computed and has to
    # be observed and published. {Data::Eop} supplies the difference.
    #
    # The conversion is UT1 = TT - delta T, not UTC + delta UT1, and that
    # choice is what lets UT1 reach any date. UTC is defined from 1961 and
    # refuses anything earlier; delta T is estimated from a polynomial fit
    # back to 1800, so a pre-1961 instant has a UT1 reading even though it can
    # never have a UTC one.
    #
    # UTC has not left the picture, though: it indexes the table. Delta T is
    # published against the UTC date, and the value moves enough between
    # neighbouring dates that asking at the wrong one shows up. Reading it at
    # the TT date is wrong by up to 1.9 microseconds, and even reading it at
    # the UT1 date rather than the UTC one is wrong by around 24 nanoseconds,
    # both of which are larger than the nanosecond the other conversions hold
    # to. So this reads delta T at the UTC date wherever UTC reaches, and at
    # the TT date before 1961, where the polynomial takes over and a shift of
    # a minute in its argument moves the answer by less than the fit's own
    # error.
    #
    # @example
    #   instant = Horologium::Instant.from_julian_date(2_451_545.0, scale: :tt)
    #   instant.to(:ut1).as(:julian_date) # => 2451544.99926124
    class UT1 < Base
      class << self
        # A TAI Julian Date, read in UT1. It reads TAI in TT, asks for delta T
        # at the UTC date, and takes it off.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UT1, in days
        # @raise [OutOfDataRangeError] where delta T is not published
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def from_reference(value, precision)
          in_tt = TT.from_reference(value, precision)
          subtract_delta_t(in_tt, index_date(value, in_tt), precision)
        end

        # A UT1 Julian Date, read back in TAI. UT1 is within a second of UTC,
        # so the UT1 date is a good enough key to find the TAI of the instant,
        # and the UTC date that follows from it is the key delta T is really
        # published against. Reading it twice is what makes the two directions
        # agree to the last nanosecond rather than to about 24 of them.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UT1, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @raise [OutOfDataRangeError] where delta T is not published
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def to_reference(value, precision)
          approximate_tt = Numeric::Precision.add(
            value,
            bootstrap_offset(value, precision)
          )
          approximate = TT.to_reference(approximate_tt, precision)

          in_tt = add_delta_t(
            value,
            index_date(approximate, approximate_tt),
            precision
          )
          TT.to_reference(in_tt, precision)
        end

        # Where the delta T behind a reading came from: +:measured+ where the
        # published series observed it, +:extrapolated+ where the series
        # predicts it, and +:estimated+ before the series starts, where it is
        # a polynomial fit to eclipse records rather than an observation.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UT1, in days
        # A reading only exists where the conversion found a delta T, so
        # there is no out of range case to handle here.
        #
        # @return [Symbol]
        def provenance(value)
          source.provenance_at(value.to_f)
        end

        private

        # Delta T for the first pass, in days. The UT1 coordinate is the
        # natural key for it, and a good one everywhere except within delta T
        # of the lower edge of the data, where the coordinate sits just
        # outside a range the instant itself is inside: the conversion out
        # subtracted delta T to get here, so a UT1 value can be a few seconds
        # earlier than the earliest date the source answers for. A day on is
        # back inside, and delta T moves by about a millisecond over a day at
        # that end of the fit, which is far closer than this pass needs to be.
        # The second lookup is the one that decides the answer.
        #
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] delta T in days
        # @raise [OutOfDataRangeError] where neither date is published
        def bootstrap_offset(value, precision)
          in_days(value.to_f, precision)
        rescue OutOfDataRangeError
          in_days(value.to_f + 1, precision)
        end

        # The Julian Date to look delta T up at: the UTC one where UTC reaches
        # the instant, the TT one before that. UTC is only ever the key here,
        # never a step in the conversion, so a date UTC cannot name still
        # reads in UT1.
        #
        # @param in_tai [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the instant in TAI
        # @param in_tt [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the same instant in TT
        # @return [Float] the Julian Date to read delta T at
        def index_date(in_tai, in_tt)
          UTC.from_reference(in_tai, :standard).to_f
        rescue OutOfRangeError
          in_tt.to_f
        end

        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact]
        def subtract_delta_t(in_tt, julian_date, precision)
          Numeric::Precision.subtract(in_tt, in_days(julian_date, precision))
        end

        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact]
        def add_delta_t(value, julian_date, precision)
          Numeric::Precision.add(value, in_days(julian_date, precision))
        end

        # Delta T at a Julian Date, in days, at the given precision.
        #
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact]
        # @raise [OutOfDataRangeError] where delta T is not published
        def in_days(julian_date, precision)
          seconds = source.delta_t_at(julian_date)
          Numeric::Precision.build(seconds, precision) /
            Duration::SECONDS_PER_DAY
        rescue IERS::OutOfRangeError => e
          raise OutOfDataRangeError,
            "delta T, the difference between TT and UT1, is not published " \
            "for this date, so it cannot be read in UT1: #{e.message}"
        end

        # @return [#delta_t_at, #provenance_at]
        def source
          Horologium.configuration.eop_source
        end
      end
    end
  end
end
