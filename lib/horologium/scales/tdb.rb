# frozen_string_literal: true

module Horologium
  module Scales
    # Barycentric Dynamical Time, the scale the planetary ephemerides are
    # written in. It keeps almost the rate of TT, apart from periodic
    # relativistic terms worth at most about two milliseconds;
    # {Data::BarycentricModel} gives the difference. TDB is defined on TT, so
    # this conversion goes through TT, which is a fixed 32.184 seconds from
    # TAI.
    #
    # The difference is a floating-point model, so unlike the constant offsets
    # of TAI and TT this edge is not exact, even at +:exact+. Reading the
    # model at +:exact+ stores its result faithfully, but the model itself
    # stays a float computation.
    #
    # @example
    #   instant = Horologium::Instant.from_julian_date(2_460_796.5, scale: :tt)
    #   instant.to(:tdb).as(:julian_date) # => 2460796.5000000168
    class TDB < Base
      class << self
        # A TAI Julian Date, read in TDB. It reads TAI in TT first, then adds
        # the TDB - TT difference the model gives.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TDB, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def from_reference(value, precision)
          in_tt = TT.from_reference(value, precision)
          Numeric::Precision.add(in_tt, correction(in_tt, precision))
        end

        # A TDB Julian Date, read back in TAI. It removes the TDB - TT
        # difference, then reads the TT Julian Date back in TAI.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TDB, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def to_reference(value, precision)
          in_tt = Numeric::Precision.subtract(
            value,
            correction(value, precision)
          )
          TT.to_reference(in_tt, precision)
        end

        private

        # The TDB - TT difference at a Julian Date, in days, as a value at the
        # given precision. The model reads the date as a Float; at +:exact+
        # the difference is stored faithfully as a Rational, but it is still a
        # float the model computed.
        #
        # @param julian_date [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] a TT Julian Date on the way out, a TDB
        #   one on the way back
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the difference, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def correction(julian_date, precision)
          seconds = Data::BarycentricModel.tdb_minus_tt(julian_date.to_f)
          Numeric::Precision.build(
            seconds / Duration::SECONDS_PER_DAY,
            precision
          )
        end
      end
    end
  end
end
