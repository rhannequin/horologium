# frozen_string_literal: true

module Horologium
  # The shapes an instant can be read in, once a scale has been chosen.
  # {ScaleReading#as} asks for one, and an instant is built from one. A
  # representation is given the whole reading on the way out, so it can use the
  # scale as well as the value.
  module Representations
    # The Julian Date: the number of days since noon on 1 January 4713 BC, in
    # the scale it is read in. Astronomy counts time with it, and an ephemeris
    # takes it as input.
    #
    # An instant is already stored as a Julian Date, so on the way out this
    # representation only picks the type it comes out in. At today's dates a
    # Float keeps the Julian Date to a few tens of microseconds, which is where
    # the other types come in.
    #
    # @example The type is chosen on the way out
    #   instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)
    #   instant.as(:julian_date, scale: :tt)                  # => Float
    #   instant.as(:julian_date, scale: :tt, as: :rational)   # => Rational
    #   instant.as(:julian_date, scale: :tt, as: :two_part)   # => TwoPartFloat
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
        # +:float+ is the default. A Float spends most of its digits on the
        # Julian Date itself, and at today's dates the numbers it can hold are
        # about 40 microseconds apart, which is enough to display, to plot, or
        # to compare at millisecond tolerance. +:rational+ keeps the whole
        # value. +:two_part+ gives the two parts, to pass to a foreign kernel
        # that reads them, such as an ERFA binding or a Chebyshev ephemeris
        # segment. They are only guaranteed to add up to the Julian Date: an
        # instant is built on the integer-day grid, but a scale conversion
        # moves the parts off it. For arithmetic, use {Duration}.
        #
        # An +:exact+ reading asked for +:two_part+ is split again, and loses
        # the precision the Rational held beyond the two parts. It only
        # happens when the caller asks for it.
        #
        # Two Float readings of one instant are too coarse to subtract. The
        # Floats around a modern Julian Date sit about 47 microseconds of time
        # apart, and the whole TDB - TT correction peaks around 1.7
        # milliseconds, so most of what the subtraction returns is the
        # rounding. At Julian Date 2460676.5 the two scales read 80.466
        # microseconds apart as Floats, where the answer is 86.463. Read both
        # as +:rational+ to compare them.
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
        # This is the way in, where {render} is the way out. The value is a
        # Julian Date in a scale, not in TAI; it is {Instant.from_julian_date}
        # that reads it back in TAI.
        #
        # The lossless shapes come first. A String and a Rational say the
        # Julian Date exactly, and a high and a low Float say it to about twice
        # what one Float holds. A single Float is the lossy one: seven of its
        # sixteen digits go to the day count, which leaves the fraction of a
        # day about 40 microseconds. Horologium stores it faithfully and does
        # not guess, but the loss happened in the literal, before the library
        # was reached.
        #
        # At +:standard+ two Floats are normalized onto the integer-day grid,
        # and a String or a Rational is split so that the two Floats carry as
        # much of it as they can hold. At +:exact+ nothing is dropped, beyond
        # what the input had already lost.
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
        # @example
        #   Horologium::Representations::JulianDate.parse(
        #     "2456463.052272",
        #     nil,
        #     Horologium::Scales::TAI,
        #     :exact
        #   )
        def parse(value, low, _scale, precision)
          return two_parts(value, low, precision) unless low.nil?

          single(value, precision)
        end

        # A value in days, in the type asked for. {render} reads the value off
        # the reading; a representation that shifts the value before rendering
        # it, such as {ModifiedJulianDate}, hands the shifted value here.
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

        # A Julian Date given as one Float. There is no low part to add to it,
        # so at +:exact+ it is the Rational the Float already spells, and at
        # +:standard+ it goes onto the integer-day grid with an empty low part.
        #
        # @param value [Float] the Julian Date, in days
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date, in days
        # @raise [UnknownPrecisionError] when the precision is not recognised
        # @raise [InvalidValueError] when the value is not a finite number
        def day(value, precision)
          Numeric::Precision.number!(value)

          if Numeric::Precision.validate!(precision) == :exact
            Numeric::Exact.new(value)
          else
            Numeric::TwoPartFloat.normalize(value, 0.0)
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
            Numeric::TwoPartFloat.normalize(day, fraction)
          end
        end

        # One part of a two-part Julian Date, as a Float. The parts are the two
        # Floats a Julian Date is split across, so a Rational part is refused:
        # a Julian Date said exactly is said as one number, not two.
        #
        # @param value [Float, Integer] the part, in days
        # @return [Float] the same part
        # @raise [InvalidValueError] when it is not a Float or an Integer
        def part(value)
          case value
          when Float, Integer
            value.to_f
          else
            raise InvalidValueError,
              "the two parts of a Julian Date are each a Float or an " \
              "Integer, got a #{value.class}; pass a String or a Rational to " \
              "give a Julian Date exactly"
          end
        end

        # A Julian Date written as a String, read as an exact Rational. The
        # String is read strictly: anything that is not digits with an optional
        # decimal fraction is refused, rather than read part way.
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

        # The value as a two-part float. An exact value is split again.
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
