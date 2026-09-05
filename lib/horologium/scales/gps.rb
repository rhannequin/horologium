# frozen_string_literal: true

module Horologium
  module Scales
    # GPS time, the scale the Global Positioning System broadcasts. It is a
    # fixed 19 SI seconds behind TAI, and it has stayed there since the system
    # started: GPS counts SI seconds and never takes a leap second, so the
    # offset is a constant and this conversion needs no external data.
    #
    # The 19 seconds are TAI - UTC on 1980-01-06, the day GPS time started
    # from zero with its clocks set to UTC. UTC has taken leap seconds since
    # and GPS has not, which is why GPS runs ahead of UTC today while staying
    # fixed against TAI.
    #
    # @example GPS is 19 seconds behind TAI
    #   instant = Horologium::Instant.from_julian_date(
    #     2_443_144.5,
    #     scale: :tai
    #   )
    #   instant.to(:gps).as(:julian_date) # => 2443144.4997800924
    class GPS < Base
      # The SI seconds GPS is behind TAI.
      SECONDS_BEHIND_TAI = 19

      # The same offset in days, because a Julian Date counts days.
      DAYS_BEHIND_TAI = Rational(SECONDS_BEHIND_TAI, Duration::SECONDS_PER_DAY)

      # The offset at each precision, built once, so a conversion does not
      # build it again every time.
      #
      # @api private
      OFFSETS = Numeric::Precision.build_each(DAYS_BEHIND_TAI)
      private_constant :OFFSETS

      class << self
        # A TAI Julian Date, read in GPS. It removes the 19 seconds.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in GPS, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def from_reference(value, precision)
          Numeric::Precision.subtract(value, OFFSETS[precision])
        end

        # A GPS Julian Date, read back in TAI. It adds the 19 seconds.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in GPS, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def to_reference(value, precision)
          Numeric::Precision.add(value, OFFSETS[precision])
        end
      end
    end
  end
end
