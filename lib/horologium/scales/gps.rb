# frozen_string_literal: true

module Horologium
  module Scales
    # GPS time, the scale the Global Positioning System broadcasts. It counts SI
    # seconds and never takes a leap second, so it stays a fixed 19 seconds
    # behind TAI and this conversion needs no external data.
    class GPS < Base
      # The SI seconds GPS is behind TAI.
      SECONDS_BEHIND_TAI = 19

      # The same offset in days.
      DAYS_BEHIND_TAI = Rational(SECONDS_BEHIND_TAI, Duration::SECONDS_PER_DAY)

      # @api private
      OFFSETS = Numeric::Precision.build_each(DAYS_BEHIND_TAI)
      private_constant :OFFSETS

      class << self
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in GPS, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def from_reference(value, precision)
          Numeric::Precision.subtract(value, OFFSETS[precision])
        end

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
