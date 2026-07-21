# frozen_string_literal: true

module Horologium
  module Representations
    # The Modified Julian Date: the Julian Date counted from midnight on
    # 17 November 1858 instead of noon on 1 January 4713 BC, so that a modern
    # date is a five-digit number and a day begins at midnight. Geodesy and
    # Earth orientation data are published in it.
    #
    # It is the same instant, written smaller, and the smaller number is worth
    # something: a Float spends fewer of its digits on the day count, so about
    # 2 microseconds are left for the fraction of a day where a Julian Date has
    # about 40. The lossless shapes of {JulianDate.parse} are still the way to
    # give one exactly.
    #
    # @example
    #   instant = Horologium::Instant.from_modified_julian_date(
    #     60_796.0,
    #     scale: :tai
    #   )
    #   instant.as(:julian_date, scale: :tai)           # => 2460796.5
    #   instant.as(:modified_julian_date, scale: :tai)  # => 60796.0
    class ModifiedJulianDate
      # The days between the two origins: the Modified Julian Date origin
      # falls this many days after the Julian Date origin, so a Modified
      # Julian Date is the Julian Date minus this.
      DAYS_AFTER_JULIAN_DATE_ORIGIN = Rational(4_800_001, 2)

      # The offset at each precision, built once, so a reading does not build
      # it again every time.
      #
      # @api private
      OFFSETS = Numeric::Precision::NAMES.to_h do |precision|
        [
          precision,
          Numeric::Precision.build(DAYS_AFTER_JULIAN_DATE_ORIGIN, precision)
        ]
      end.freeze
      private_constant :OFFSETS

      class << self
        # The Modified Julian Date, in the type asked for. The types are the
        # ones a Julian Date comes out as, {JulianDate::OUTPUTS}, and they mean
        # the same here.
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
              offset(reading.precision)
            ),
            output
          )
        end

        # A Modified Julian Date as it was given, as a Julian Date in days, at
        # the precision asked for. It takes the shapes {JulianDate.parse}
        # takes, and adds the days between the two origins.
        #
        # @param value [String, Rational, Integer, Float] the Modified Julian
        #   Date, in days, or its high part when a low part follows
        # @param low [Float, Integer, nil] the low part, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date, in days
        # @raise [ParseError] when a String does not spell a Modified Julian
        #   Date
        # @raise [ArgumentError] when it is none of the shapes above
        # @raise [UnknownPrecisionError] when the precision is not recognised
        # @example
        #   Horologium::Representations::ModifiedJulianDate.parse(
        #     "60796.052272",
        #     nil,
        #     :exact
        #   )
        def parse(value, low, precision)
          Numeric::Precision.add(
            JulianDate.parse(value, low, precision),
            offset(precision)
          )
        end

        private

        # The days between the two origins, at the given precision.
        #
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the offset, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def offset(precision)
          OFFSETS.fetch(Numeric::Precision.validate!(precision))
        end
      end
    end
  end
end
