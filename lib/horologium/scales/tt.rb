# frozen_string_literal: true

module Horologium
  module Scales
    # Terrestrial Time, the scale the theories of the solar system motion are
    # written in, and the one an ephemeris expects. It is exactly 32.184 SI
    # seconds ahead of TAI. The offset is fixed by definition, so this
    # conversion needs no external data.
    #
    # The 32.184 seconds come from Ephemeris Time, the scale used before
    # atomic clocks. TT continues it, and the offset is the gap between the
    # two when TAI took over.
    #
    # @example At the origin epoch, TT is 32.184 s ahead of TAI
    #   instant = Horologium::Instant.from_julian_date(
    #     2_443_144.5,
    #     scale: :tai
    #   )
    #   instant.to(:tt).as(:julian_date) # => 2443144.5003725
    class TT < Base
      # The SI seconds TT is ahead of TAI.
      SECONDS_AHEAD_OF_TAI = Rational(32_184, 1_000)

      # The same offset in days, because a Julian Date counts days.
      DAYS_AHEAD_OF_TAI = SECONDS_AHEAD_OF_TAI / Duration::SECONDS_PER_DAY

      # The offset at each precision, built once, so a conversion does not
      # build it again every time.
      #
      # @api private
      OFFSETS = Numeric::Precision::NAMES.map do |precision|
        [precision, Numeric::Precision.build(DAYS_AHEAD_OF_TAI, precision)]
      end.to_h.freeze
      private_constant :OFFSETS

      class << self
        # A TAI Julian Date, read in TT. It adds the 32.184 seconds.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TT, in days
        def from_reference(value, precision)
          Numeric::Precision.add(value, offset(precision))
        end

        # A TT Julian Date, read back in TAI. It removes the 32.184 seconds.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TT, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        def to_reference(value, precision)
          Numeric::Precision.subtract(value, offset(precision))
        end

        private

        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the offset in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def offset(precision)
          OFFSETS.fetch(precision) do
            raise UnknownPrecisionError.new(
              precision,
              Numeric::Precision::NAMES
            )
          end
        end
      end
    end
  end
end
