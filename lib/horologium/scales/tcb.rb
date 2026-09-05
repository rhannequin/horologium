# frozen_string_literal: true

module Horologium
  module Scales
    # Barycentric Coordinate Time, the coordinate time of a reference frame at
    # the barycentre of the solar system, outside the gravity wells of the Sun
    # and the planets. A clock there ticks faster than one on the Earth, so
    # TCB runs ahead of TDB at a fixed rate of about 0.49 seconds a year. The
    # rate is a defining constant, so the TCB to TDB edge needs no external
    # data.
    #
    # TCB is defined on TDB, so this conversion goes through it. TDB itself
    # rests on the floating-point {Data::BarycentricModel}, so while the TCB
    # to TDB edge is exact, the whole conversion from TAI inherits the model's
    # accuracy the way {TDB} does. Reading TCB back in TAI still returns the
    # value given, because each edge undoes itself.
    #
    # The scales were set to read the same at {TT_TCG_TCB_ORIGIN_JULIAN_DATE},
    # 1977-01-01 00:00:00 TAI, up to the small constant {TDB_0} that keeps TDB
    # continuous with the scale it replaced.
    #
    # @example TCB runs ahead of TDB
    #   instant = Horologium::Instant.from_julian_date(
    #     2_451_545.0,
    #     scale: :tt
    #   )
    #   instant.to(:tcb).as(:julian_date) # => 2451545.000130251
    class TCB < Base
      # L_B, the defining constant 1 - d(TDB)/d(TCB). It is exact by
      # definition, not a measurement, so it is held as a Rational.
      L_B = Rational(1_550_519_768, 10**17)

      # The fixed offset in the TDB definition, in SI seconds. It is what
      # keeps TDB continuous with the ephemeris time scale it replaced, and it
      # is why TDB and TCB do not read exactly the same at the origin.
      TDB_0 = Rational(-655, 10**7)

      # The same offset in days, because a Julian Date counts days.
      TDB_0_IN_DAYS = TDB_0 / Duration::SECONDS_PER_DAY

      # The rate TDB gains on TCB, L_B / (1 - L_B). Going from TDB to TCB
      # multiplies by this; coming back multiplies by {L_B}, which is what
      # makes the pair exact inverses.
      #
      # @api private
      RATE_FROM_TDB = L_B / (1 - L_B)
      private_constant :RATE_FROM_TDB

      # The origin and the TDB offset at each precision, built once, so a
      # conversion does not build them again every time.
      #
      # @api private
      ORIGINS = Numeric::Precision.build_each(TT_TCG_TCB_ORIGIN_JULIAN_DATE)
      private_constant :ORIGINS

      # @api private
      OFFSETS = Numeric::Precision.build_each(TDB_0_IN_DAYS)
      private_constant :OFFSETS

      class << self
        # A TAI Julian Date, read in TCB. It reads TAI in TDB first, takes the
        # {TDB_0} offset off, then adds the rate over the time since the
        # origin.
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
          Numeric::Precision.add(shifted, elapsed * RATE_FROM_TDB)
        end

        # A TCB Julian Date, read back in TAI. It removes the rate over the
        # time since the origin, puts the {TDB_0} offset back, then reads the
        # TDB Julian Date in TAI.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TCB, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def to_reference(value, precision)
          elapsed = Numeric::Precision.subtract(value, ORIGINS[precision])
          shifted = Numeric::Precision.subtract(value, elapsed * L_B)
          in_tdb = Numeric::Precision.add(shifted, OFFSETS[precision])
          TDB.to_reference(in_tdb, precision)
        end
      end
    end
  end
end
