# frozen_string_literal: true

module Horologium
  module Scales
    # Geocentric Coordinate Time, the coordinate time of a reference frame
    # moving with the centre of the Earth but outside its gravity well. A
    # clock there ticks slightly faster than one on the geoid, so TCG runs
    # ahead of TT at a fixed rate. The rate is a defining constant, so this
    # conversion needs no external data and no model.
    #
    # TT and TCG were set to read the same at
    # {TT_TCG_TCB_ORIGIN_JULIAN_DATE}, 1977-01-01 00:00:00 TAI, and the
    # difference has grown by about 22 milliseconds a year since. TCG is
    # defined on TT, so this conversion goes through TT, which is a fixed
    # 32.184 seconds from TAI.
    #
    # Unlike {TDB}, this edge is exact at +:exact+: the rate is a rational
    # constant, and reading TCG back in TT undoes the conversion exactly.
    #
    # @example TCG and TT read the same at the origin
    #   instant = Horologium::Instant.from_julian_date(
    #     2_443_144.5,
    #     scale: :tai
    #   )
    #   instant.to(:tcg).as(:julian_date) # => 2443144.5003725
    class TCG < Base
      # L_G, the defining constant 1 - d(TT)/d(TCG). It is exact by
      # definition, not a measurement, so it is held as a Rational.
      L_G = Rational(6_969_290_134, 10**19)

      # The rate TT gains on TCG, L_G / (1 - L_G). Going from TT to TCG
      # multiplies by this; coming back multiplies by {L_G}, which is what
      # makes the pair exact inverses.
      #
      # @api private
      RATE_FROM_TT = L_G / (1 - L_G)
      private_constant :RATE_FROM_TT

      # The origin at each precision, built once, so a conversion does not
      # build it again every time.
      #
      # @api private
      ORIGINS = Numeric::Precision.build_each(TT_TCG_TCB_ORIGIN_JULIAN_DATE)
      private_constant :ORIGINS

      class << self
        # A TAI Julian Date, read in TCG. It reads TAI in TT first, then adds
        # the rate over the time since the origin.
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
          Numeric::Precision.add(in_tt, elapsed * RATE_FROM_TT)
        end

        # A TCG Julian Date, read back in TAI. It removes the rate over the
        # time since the origin, then reads the TT Julian Date back in TAI.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TCG, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def to_reference(value, precision)
          elapsed = Numeric::Precision.subtract(value, ORIGINS[precision])
          in_tt = Numeric::Precision.subtract(value, elapsed * L_G)
          TT.to_reference(in_tt, precision)
        end
      end
    end
  end
end
