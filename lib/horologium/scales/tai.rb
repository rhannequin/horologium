# frozen_string_literal: true

module Horologium
  module Scales
    # International Atomic Time, the scale atomic clocks keep. The library
    # stores an instant as a TAI Julian Date, so reading an instant in TAI
    # returns the value it already holds.
    #
    # @example
    #   instant = Horologium::Instant.from_julian_date(
    #     2_443_144.5,
    #     scale: :tai
    #   )
    #   instant.to(:tai).as(:julian_date) # => 2443144.5
    class TAI < Base
      class << self
        # The value, unchanged. Instants are stored in TAI.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param _precision [Symbol] +:standard+ or +:exact+, unused here
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the same value
        def from_reference(value, _precision)
          value
        end

        # The value, unchanged. Instants are stored in TAI.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param _precision [Symbol] +:standard+ or +:exact+, unused here
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the same value
        def to_reference(value, _precision)
          value
        end
      end
    end
  end
end
