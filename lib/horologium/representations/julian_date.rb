# frozen_string_literal: true

module Horologium
  # The shapes an instant can be read in, once a scale has been chosen.
  # {ScaleReading#as} asks for one. A representation is given the whole
  # reading, so it can use the scale as well as the value.
  module Representations
    # The Julian Date: the number of days since noon on 1 January 4713 BC, in
    # the scale it is read in. Astronomy counts time with it, and an ephemeris
    # takes it as input.
    #
    # An instant is already stored as a Julian Date, so this representation
    # only picks the type it comes out in. At today's dates a Float keeps the
    # Julian Date to a few tens of microseconds, which is where the other
    # types come in.
    #
    # @example The type is chosen on the way out
    #   instant = Horologium::Instant.from_tai_julian_date(2_443_144.5)
    #   instant.as(:julian_date, scale: :tt)                  # => Float
    #   instant.as(:julian_date, scale: :tt, as: :rational)   # => Rational
    #   instant.as(:julian_date, scale: :tt, as: :two_part)   # => TwoPartFloat
    class JulianDate
      # The types a Julian Date can come out as.
      OUTPUTS = %i[float rational two_part].freeze

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
        # @param reading [Horologium::ScaleReading] the instant, read in a
        #   scale
        # @param output [Symbol] one of {OUTPUTS}
        # @return [Float, Rational, Horologium::Numeric::TwoPartFloat]
        # @raise [UnknownOutputError] when the output type is not one of
        #   {OUTPUTS}
        def render(reading, output)
          value = reading.value

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

        # The value as a two-part float. An exact value is split again.
        #
        # @param value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date, in days
        # @return [Horologium::Numeric::TwoPartFloat]
        def two_part(value)
          return value if value.is_a?(Numeric::TwoPartFloat)

          Numeric::TwoPartFloat.from_real(value.to_r)
        end
      end
    end
  end
end
