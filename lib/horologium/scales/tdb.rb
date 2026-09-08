# frozen_string_literal: true

module Horologium
  module Scales
    # Barycentric Dynamical Time, the scale the planetary ephemerides are
    # written in. It keeps almost the rate of TT, apart from periodic
    # relativistic terms worth at most about two milliseconds;
    # {Data::BarycentricModel} gives the difference.
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
        # given precision.
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
          Numeric::Precision.build(seconds, precision) /
            Duration::SECONDS_PER_DAY
        end
      end
    end
  end
end
