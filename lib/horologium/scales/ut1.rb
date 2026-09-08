# frozen_string_literal: true

module Horologium
  module Scales
    # Universal Time, the scale the rotation of the Earth keeps. It is the one
    # scale here that is measured rather than defined, so it needs published
    # data: {Data::Eop} supplies delta T. The conversion is UT1 = TT - delta T,
    # not UTC + delta UT1.
    class UT1 < Base
      class << self
        # Reads TAI in TT, asks for delta T at the UTC date, takes it off.
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

        # Reads delta T twice: once at the UT1 date, which is within a second of
        # UTC and good enough to find the instant, then again at the UTC date
        # that follows from it, which is the key delta T is published against.
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

        # Where the delta T behind a reading came from: +:measured+ if the
        # series observed it, +:extrapolated+ if the series predicts it, and
        # +:estimated+ if the polynomial fit answered instead.
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

        # Delta T for the first pass, in days.
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
        # the instant, the TT one where it doesn't.
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

        # The date to read delta T at, held at the horizon once past it.
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
        # {to_reference}.
        #
        # @param julian_date [Float]
        # @return [Float]
        def clamped(julian_date)
          limit = horizon_date
          (limit && julian_date > limit) ? limit : julian_date
        end

        # The date the delta T behind a reading was read at.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in UT1, in days
        # @return [Float]
        def reading_index_date(value)
          in_tai = to_reference(value, :standard)
          index_date(in_tai, TT.from_reference(in_tai, :standard))
        end

        # False when the source cannot say, so there is no horizon.
        #
        # @param julian_date [Float]
        # @return [Boolean]
        def past_horizon?(julian_date)
          limit = horizon_date
          !limit.nil? && julian_date > limit
        end

        # The Julian Date the Earth orientation data reaches, or nil when the
        # source cannot say.
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
