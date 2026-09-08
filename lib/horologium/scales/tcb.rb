# frozen_string_literal: true

module Horologium
  module Scales
    # Barycentric Coordinate Time, the coordinate time of a frame at the
    # barycentre of the solar system. A clock there ticks faster than one on the
    # Earth, so TCB gains on TDB at the rate L_B, about half a second a year.
    #
    # Source:
    #  Title: IAU 2006 Resolution B3
    #  Implementation: ERFA eraTdbtcb and eraTcbtdb
    class TCB < Base
      # L_B, the defining constant 1 - d(TDB)/d(TCB), held as a Rational
      # because it is exact by definition.
      L_B = Rational(1_550_519_768, 10**17)

      # The fixed offset in the TDB definition, in SI seconds. It keeps TDB
      # continuous with the ephemeris time scale it replaced, and it is why TDB
      # and TCB don't read quite the same at the origin.
      TDB_0 = Rational(-655, 10**7)

      # The same offset in days.
      TDB_0_IN_DAYS = TDB_0 / Duration::SECONDS_PER_DAY

      # The rate TCB gains on TDB. Going out multiplies by this and coming
      # back multiplies by {L_B}, which makes the pair exact inverses.
      #
      # @api private
      RATE_FROM_TDB = L_B / (1 - L_B)
      private_constant :RATE_FROM_TDB

      # The rates at each precision. A two-part float multiplies by a Float,
      # and these denominators are wide enough that converting them on every
      # call costs more than the arithmetic does.
      #
      # @api private
      RATES = {standard: RATE_FROM_TDB.to_f, exact: RATE_FROM_TDB}.freeze
      private_constant :RATES

      # @api private
      BACK_RATES = {standard: L_B.to_f, exact: L_B}.freeze
      private_constant :BACK_RATES

      # @api private
      ORIGINS = Numeric::Precision.build_each(TT_TCG_TCB_ORIGIN_JULIAN_DATE)
      private_constant :ORIGINS

      # @api private
      OFFSETS = Numeric::Precision.build_each(TDB_0_IN_DAYS)
      private_constant :OFFSETS

      class << self
        # Reads TAI in TDB, takes the {TDB_0} offset off, then adds the rate
        # over the time since the origin.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TCB, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def from_reference(value, precision)
          in_tdb = TDB.from_reference(value, precision)
          shifted = Numeric::Precision.subtract(in_tdb, OFFSETS[precision])
          elapsed = Numeric::Precision.subtract(shifted, ORIGINS[precision])
          Numeric::Precision.add(shifted, elapsed * RATES[precision])
        end

        # Removes the rate over the time since the origin, puts the {TDB_0}
        # offset back, then reads the TDB Julian Date in TAI.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TCB, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def to_reference(value, precision)
          elapsed = Numeric::Precision.subtract(value, ORIGINS[precision])
          shifted = Numeric::Precision.subtract(
            value,
            elapsed * BACK_RATES[precision]
          )
          in_tdb = Numeric::Precision.add(shifted, OFFSETS[precision])
          TDB.to_reference(in_tdb, precision)
        end
      end
    end
  end
end
