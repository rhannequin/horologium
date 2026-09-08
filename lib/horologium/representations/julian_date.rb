# frozen_string_literal: true

module Horologium
  # The shapes an instant can be read in, once a scale has been chosen.
  # {ScaleReading#as} asks for one, and an instant is built from one.
  module Representations
    # The Julian Date: the number of days since noon on 1 January 4713 BC, in
    # the scale it is read in. Astronomy counts time with it, and an ephemeris
    # takes it as input.
    class JulianDate
      # The types a Julian Date can come out as.
      OUTPUTS = %i[float rational two_part].freeze

      # The shape a Julian Date written as a String takes: digits, with an
      # optional sign and an optional decimal fraction. There is no exponent,
      # because a Julian Date is not written with one.
      #
      # @api private
      DECIMAL = /\A[+-]?\d+(\.\d+)?\z/
      private_constant :DECIMAL

      class << self
        # The Julian Date, in the type asked for.
        #
        # @param reading [Horologium::ScaleReading] the instant, read in a
        #   scale
        # @param output [Symbol] one of {OUTPUTS}
        # @return [Float, Rational, Horologium::Numeric::TwoPartFloat]
        # @raise [UnknownOutputError] when the output type is not one of
        #   {OUTPUTS}
        def render(reading, output)
          render_value(reading.value, output)
        end

        # A Julian Date as it was given, in days, at the precision asked for.
        #
        # @param value [String, Rational, Integer, Float] the Julian Date, in
        #   days, or its high part when a low part follows
        # @param low [Float, Integer, nil] the low part of the Julian Date, in
        #   days
        # @param _scale [Class] the scale the value is read in, unused: a
        #   Julian Date means the same in every scale
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date, in days
        # @raise [ParseError] when a String does not spell a Julian Date
        # @raise [InvalidValueError] when the Julian Date is none of the shapes
        #   above
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def parse(value, low, _scale, precision)
          return two_parts(value, low, precision) unless low.nil?

          single(value, precision)
        end

        # A value in days, in the type asked for.
        #
        # @api private
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the value, in days
        # @param output [Symbol] one of {OUTPUTS}
        # @return [Float, Rational, Horologium::Numeric::TwoPartFloat]
        # @raise [UnknownOutputError] when the output type is not one of
        #   {OUTPUTS}
        def render_value(value, output)
          case output
          when :float
            value.to_f
          when :rational
            value.to_r
          when :two_part
            two_part(value)
          else
            raise UnknownOutputError.new(output, OUTPUTS)
          end
        end

        private

        # A Julian Date given as a single number.
        #
        # @param value [String, Rational, Integer, Float]
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date, in days
        # @raise [ParseError] when a String does not spell a Julian Date
        # @raise [InvalidValueError] when it is not a number the library reads
        def single(value, precision)
          case value
          when String
            Numeric::Precision.build(decimal(value), precision)
          when Rational, Integer
            Numeric::Precision.build(value, precision)
          when Float
            day(value, precision)
          else
            raise InvalidValueError,
              "a Julian Date is a String, a Rational, an Integer, a Float, " \
              "or a high and a low part each a Float or an Integer, got a " \
              "#{value.class}"
          end
        end

        # A Julian Date given as one Float.
        #
        # @param value [Float] the Julian Date, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        # @raise [InvalidValueError] when the value is not a finite number
        def day(value, precision)
          number = Numeric::Precision.finite_float!(value)

          if Numeric::Precision.validate!(precision) == :exact
            Numeric::Exact.new(value)
          else
            Numeric::TwoPartFloat.normalized(number, 0.0)
          end
        end

        # A Julian Date given as a high and a low part, the shape it is stored
        # in.
        #
        # @param high [Float, Integer] the high part, in days
        # @param low [Float, Integer] the low part, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date, in days
        # @raise [InvalidValueError] when either part is not a Float or an
        #   Integer
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def two_parts(high, low, precision)
          day = part(high)
          fraction = part(low)

          if Numeric::Precision.validate!(precision) == :exact
            Numeric::Exact.new(Numeric::TwoPartFloat.new(day, fraction))
          else
            Numeric::TwoPartFloat.normalized(day, fraction)
          end
        end

        # One part of a two-part Julian Date, as a Float.
        #
        # @param value [Float, Integer] the part, in days
        # @return [Float] the same part
        # @raise [InvalidValueError] when it is not a Float or an Integer
        def part(value)
          case value
          when Float, Integer
            Numeric::Precision.finite_float!(value)
          else
            raise InvalidValueError,
              "the two parts of a Julian Date are each a Float or an " \
              "Integer, got a #{value.class}; pass a String or a Rational to " \
              "give a Julian Date exactly"
          end
        end

        # A Julian Date written as a String, read as an exact Rational.
        #
        # @param string [String] the Julian Date, written out
        # @return [Rational] the Julian Date, exactly
        # @raise [ParseError] when the String does not spell a Julian Date
        def decimal(string)
          unless DECIMAL.match?(string)
            raise ParseError,
              "cannot read #{string.inspect} as a Julian Date; it is written " \
              "as digits with an optional decimal fraction, such as " \
              "\"2456463.052272\""
          end

          Rational(string)
        end

        # The value as a two-part float.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the value, in days
        # @return [Horologium::Numeric::TwoPartFloat]
        def two_part(value)
          return value if value.is_a?(Numeric::TwoPartFloat)

          Numeric::TwoPartFloat.from_real(value.to_r)
        end
      end
    end
  end
end
