# frozen_string_literal: true

module Horologium
  module Scales
    # International Atomic Time, the scale atomic clocks keep. The library
    # stores an instant as a TAI Julian Date. Reading an instant in TAI
    # returns the value it already holds.
    class TAI < Base
      class << self
        # The value, unchanged: instants are stored in TAI.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact]
        # @param _precision [Symbol] unused here
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact]
        def from_reference(value, _precision)
          value
        end

        # The value, unchanged: instants are stored in TAI.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact]
        # @param _precision [Symbol] unused here
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact]
        def to_reference(value, _precision)
          value
        end
      end
    end
  end
end
