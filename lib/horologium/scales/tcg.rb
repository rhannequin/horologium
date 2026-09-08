# frozen_string_literal: true

module Horologium
  module Scales
    # Geocentric Coordinate Time, the coordinate time of a frame moving with the
    # centre of the Earth but outside its gravity well. A clock there ticks
    # slightly faster than one on the geoid, so TCG gains on TT at the rate L_G,
    # about 22 milliseconds a year.
    #
    # Source:
    #  Title: IAU 1991 Resolution A4, Recommendation IV
    #  Also: IAU 2000 Resolution B1.9
    #  Implementation: ERFA eraTttcg and eraTcgtt
    class TCG < Base
      # L_G, the defining constant 1 - d(TT)/d(TCG), held as a Rational
      # because it is exact by definition.
      L_G = Rational(6_969_290_134, 10**19)

      # The rate TCG gains on TT. Going out multiplies by this and coming
      # back multiplies by {L_G}, which makes the pair exact inverses.
      #
      # @api private
      RATE_FROM_TT = L_G / (1 - L_G)
      private_constant :RATE_FROM_TT

      # The rates at each precision. A two-part float multiplies by a Float,
      # and these denominators are wide enough that converting them on every
      # call costs more than the arithmetic does.
      #
      # @api private
      RATES = {standard: RATE_FROM_TT.to_f, exact: RATE_FROM_TT}.freeze
      private_constant :RATES

      # @api private
      BACK_RATES = {standard: L_G.to_f, exact: L_G}.freeze
      private_constant :BACK_RATES

      # @api private
      ORIGINS = Numeric::Precision.build_each(TT_TCG_TCB_ORIGIN_JULIAN_DATE)
      private_constant :ORIGINS

      class << self
        # Reads TAI in TT, then adds the rate over the time since the origin.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TCG, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def from_reference(value, precision)
          in_tt = TT.from_reference(value, precision)
          elapsed = Numeric::Precision.subtract(in_tt, ORIGINS[precision])
          Numeric::Precision.add(in_tt, elapsed * RATES[precision])
        end

        # Removes the rate over the time since the origin, then reads the TT
        # Julian Date back in TAI.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TCG, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def to_reference(value, precision)
          elapsed = Numeric::Precision.subtract(value, ORIGINS[precision])
          in_tt = Numeric::Precision.subtract(
            value,
            elapsed * BACK_RATES[precision]
          )
          TT.to_reference(in_tt, precision)
        end
      end
    end
  end
end
