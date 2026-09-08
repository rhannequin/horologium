# frozen_string_literal: true

module Horologium
  module Representations
    # The Modified Julian Date: the Julian Date counted from midnight on 17
    # November 1858 instead of noon on 1 January 4713 BC, so that a modern date
    # is a five-digit number and a day begins at midnight. Geodesy and Earth
    # orientation data are published in it.
    class ModifiedJulianDate
      # The days between the two origins: the Modified Julian Date origin
      # falls this many days after the Julian Date origin. A Modified
      # Julian Date is the Julian Date minus this.
      DAYS_AFTER_JULIAN_DATE_ORIGIN = Rational(4_800_001, 2)

      # The offset at each precision, built once. A reading doesn't build
      # it again every time.
      #
      # @api private
      OFFSETS = Numeric::Precision.build_each(DAYS_AFTER_JULIAN_DATE_ORIGIN)
      private_constant :OFFSETS

      class << self
        # The Modified Julian Date, in the type asked for.
        #
        # @param reading [Horologium::ScaleReading] the instant, read in a
        #   scale
        # @param output [Symbol] one of {JulianDate::OUTPUTS}
        # @return [Float, Rational, Horologium::Numeric::TwoPartFloat]
        # @raise [UnknownOutputError] when the output type is not one of
        #   {JulianDate::OUTPUTS}
        def render(reading, output)
          JulianDate.render_value(
            Numeric::Precision.subtract(
              reading.value,
              OFFSETS[reading.precision]
            ),
            output
          )
        end

        # A Modified Julian Date as it was given, as a Julian Date in days, at
        # the precision asked for.
        #
        # @param value [String, Rational, Integer, Float] the Modified Julian
        #   Date, in days, or its high part when a low part follows
        # @param low [Float, Integer, nil] the low part, in days
        # @param scale [Class] the scale the value is read in, passed on to
        #   {JulianDate.parse}, which doesn't use it
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date, in days
        # @raise [ParseError] when a String does not spell a Modified Julian
        #   Date
        # @raise [InvalidValueError] when it is none of the shapes above
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def parse(value, low, scale, precision)
          Numeric::Precision.add(
            JulianDate.parse(value, low, scale, precision),
            OFFSETS[precision]
          )
        end
      end
    end
  end
end
