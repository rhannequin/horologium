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
          subtract_delta_t(
            in_tt,
            within_horizon(index_date(value, in_tt)),
            precision
          )
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
            within_horizon(index_date(approximate, approximate_tt)),
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
          julian_date = reading_index_date(value)
          return :extrapolated if past_horizon?(julian_date)

          source.provenance_at(julian_date)
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
          in_days(clamped(value.to_f), precision)
        rescue OutOfDataRangeError
          in_days(clamped(value.to_f + 1), precision)
        end

        # The Julian Date to look delta T up at: the UTC one where UTC reaches
        # the instant, the TT one where it does not. UTC is only ever the key
        # here, never a step in the conversion, so a date UTC cannot name
        # still reads in UT1.
        #
        # +leap_second_horizon+ is UTC's policy about UTC readings, and it has
        # no business deciding whether UT1 answers, so a strict refusal from
        # it falls back the same way a pre-1961 date does rather than
        # propagating. The key is then the TT date, which is out by up to 1.9
        # microseconds, and that only happens past the leap second horizon in
        # a mode the caller opted into.
        #
        # @param in_tai [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the instant in TAI
        # @param in_tt [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the same instant in TT
        # @return [Float] the Julian Date to read delta T at
        def index_date(in_tai, in_tt)
          UTC.from_reference(in_tai, :standard).to_f
        rescue OutOfRangeError, OutOfDataRangeError
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

        # The date to read delta T at, held at the horizon once past it. The
        # Earth's rotation is not going to be revised backwards, and the leap
        # second system keeps UT1 within 0.9 s of UTC, so the last published
        # delta T carries a bounded error rather than an unknown one. The
        # reading says +:extrapolated+, and a caller who must not compute on
        # one sets +ut1_horizon+ to +:raise+.
        #
        # @param julian_date [Float] the date the conversion wants
        # @return [Float] that date, or the horizon where it is past it
        # @raise [OutOfDataRangeError] in strict mode, past the horizon
        def within_horizon(julian_date)
          limit = horizon_date
          return julian_date unless limit && julian_date > limit
          return limit unless strict?

          raise OutOfDataRangeError,
            "the Earth orientation data reaches Julian Date #{limit}, and " \
            "this moment is after it, where the rotation has not been " \
            "measured yet. ut1_horizon is :raise, so it is refused; set it " \
            "to :extrapolate to read it with the last published delta T."
        end

        # The same clamp with no policy attached, for the first pass of
        # {to_reference}. That pass reads a UT1 coordinate rather than the UTC
        # one the horizon is stated in, and the two sit up to 0.9 s apart,
        # which is enough to put an instant the data covers on the far side of
        # the line. Refusing there would refuse a covered instant, so this
        # clamps and says nothing; the lookup that decides the answer runs
        # through {within_horizon} and carries the policy.
        #
        # @param julian_date [Float]
        # @return [Float]
        def clamped(julian_date)
          limit = horizon_date
          (limit && julian_date > limit) ? limit : julian_date
        end

        # The date the delta T behind a reading was read at. Provenance
        # describes that value, so it has to be asked at the same date, not at
        # the UT1 coordinate the reading is expressed in.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UT1, in days
        # @return [Float]
        def reading_index_date(value)
          in_tai = to_reference(value, :standard)
          index_date(in_tai, TT.from_reference(in_tai, :standard))
        end

        # Whether a date is past the point the Earth orientation data reaches.
        # False when the source cannot say, so there is no horizon.
        #
        # @param julian_date [Float]
        # @return [Boolean]
        def past_horizon?(julian_date)
          limit = horizon_date
          !limit.nil? && julian_date > limit
        end

        # The Julian Date the Earth orientation data reaches, from the source
        # when it can say, or nil. A source answering +covers_until+ with
        # anything but a number or nil is refused here rather than failing
        # obscurely when the date is compared.
        #
        # @return [Float, nil]
        # @raise [ConfigurationError] when the source's +covers_until+ is
        #   neither a number nor nil
        def horizon_date
          return nil unless source.respond_to?(:covers_until)

          case (limit = source.covers_until)
          when nil then nil
          when ::Integer, ::Float, ::Rational then limit.to_f
          else
            raise ConfigurationError,
              "an Earth orientation source's covers_until must be a number " \
              "or nil, got #{limit.inspect}"
          end
        end

        # @return [Boolean]
        def strict?
          Horologium.configuration.ut1_horizon == :raise
        end

        # @return [#delta_t_at, #provenance_at]
        def source
          Horologium.configuration.eop_source
        end
      end
    end
  end
end
