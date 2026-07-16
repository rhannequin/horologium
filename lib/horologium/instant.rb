# frozen_string_literal: true

module Horologium
  # A single point on the timeline, independent of any scale. It is stored as
  # a TAI Julian Date, in days, at a fixed precision.
  #
  # An Instant is frozen. Its precision is set when it is built, from the
  # precision in effect unless you pass one. At +:standard+ the Julian Date is
  # a {Numeric::TwoPartFloat}, at +:exact+ a {Numeric::Exact}.
  #
  # You can add or subtract a Duration, and subtract another Instant to get
  # the Duration between them. Adding two instants raises {DimensionalError}.
  # Mixing a +:standard+ and an +:exact+ operand gives an +:exact+ result.
  #
  # @example Shift an instant, then measure back to it
  #   instant = Horologium::Instant.from_tai_julian_date(2_460_000.5)
  #   later = instant + Horologium::Duration.seconds(3600)
  #   (later - instant) == Horologium::Duration.seconds(3600)
  #   # => true
  class Instant
    include PreciseValue

    # Builds an instant from a TAI Julian Date, split into a high and a low
    # part in days. At +:exact+ the two parts are kept as a Rational, with no
    # loss. At +:standard+ they are normalized so the high part sits on the
    # integer-day grid and the low part holds the fraction, in [-0.5, 0.5].
    #
    # @param high [Float] the high part of the Julian Date, in days
    # @param low [Float] the low part, in days
    # @param precision [Symbol] +:standard+ or +:exact+, taken from the
    #   precision in effect when omitted
    # @return [Horologium::Instant]
    # @example
    #   Horologium::Instant.from_tai_julian_date(2_443_144.5, 0.000_372_5)
    def self.from_tai_julian_date(
      high,
      low = 0.0,
      precision: Horologium.current_precision
    )
      value =
        case Numeric::Precision.validate!(precision)
        when :exact
          Numeric::Exact.new(Numeric::TwoPartFloat.new(high, low))
        else
          Numeric::TwoPartFloat.normalize(high, low)
        end
      new(value, precision)
    end

    # Adds a duration and returns a later instant.
    #
    # @param duration [Horologium::Duration] the amount to move forward
    # @return [Horologium::Instant]
    # @raise [DimensionalError] when given anything but a Duration
    # @example
    #   Horologium::Instant.from_tai_julian_date(2_460_000.5) +
    #     Horologium::Duration.days(1)
    def +(duration) # rubocop:disable Naming/BinaryOperatorParameterName
      unless duration.is_a?(Duration)
        raise DimensionalError,
          "cannot add a #{duration.class} to an Instant; " \
          "only a Duration shifts an Instant"
      end

      precision = Numeric::Precision.resolve(self.precision, duration.precision)
      days = seconds_to_days(duration, precision)
      self.class.new(Numeric::Precision.add(value, days), precision)
    end

    # Subtracts a duration to get an earlier instant, or another instant to
    # get the Duration between them.
    #
    # @param other [Horologium::Duration, Horologium::Instant]
    # @return [Horologium::Instant, Horologium::Duration]
    # @raise [DimensionalError] when given anything else
    # @example An earlier instant
    #   Horologium::Instant.from_tai_julian_date(2_460_000.5) -
    #     Horologium::Duration.days(1)
    # @example The Duration between two instants
    #   a = Horologium::Instant.from_tai_julian_date(2_460_000.5)
    #   b = Horologium::Instant.from_tai_julian_date(2_460_001.5)
    #   b - a == Horologium::Duration.days(1) # => true
    def -(other)
      case other
      when Duration
        precision = Numeric::Precision.resolve(self.precision, other.precision)
        days = seconds_to_days(other, precision)
        self.class.new(
          Numeric::Precision.subtract(value, days),
          precision
        )
      when Instant
        precision = Numeric::Precision.resolve(self.precision, other.precision)
        gap = Numeric::Precision.subtract(value, other.value)
        Duration.new(gap * Duration::SECONDS_PER_DAY, precision)
      else
        raise DimensionalError,
          "cannot subtract a #{other.class} from an Instant; " \
          "subtract a Duration or another Instant"
      end
    end

    # The instant read in a time scale. An instant has no scale of its own, so
    # the scale is chosen here. Take the representation from the reading it
    # returns.
    #
    # @param scale [Symbol] the name of a registered scale, such as +:tt+
    # @return [Horologium::ScaleReading]
    # @raise [UnknownScaleError] when no scale is registered under that name
    # @example
    #   instant = Horologium::Instant.from_tai_julian_date(2_443_144.5)
    #   instant.to(:tt).as(:julian_date) # => 2443144.5003725
    def to(scale)
      reading = Horologium.configuration
        .scale(scale)
        .from_reference(value, precision)

      ScaleReading.new(scale, reading, precision)
    end

    # The instant in a representation, read in a scale. This is the shorthand
    # for +to(scale).as(representation)+.
    #
    # @param representation [Symbol] the representation, such as +:julian_date+
    # @param scale [Symbol] the name of a registered scale, such as +:tt+
    # @param as [Symbol] the type to come out as
    # @return [Object] the instant, in that representation
    # @raise [UnknownScaleError] when no scale is registered under that name
    # @raise [UnknownRepresentationError] when the representation is not one
    #   the library has
    # @example
    #   instant = Horologium::Instant.from_tai_julian_date(2_443_144.5)
    #   instant.as(:julian_date, scale: :tt, as: :rational)
    def as(representation, scale:, as: :float)
      to(scale).as(representation, as: as)
    end

    # Whether two instants fall within a tolerance of each other. Use this
    # rather than +==+ in scientific code.
    #
    # @param other [Horologium::Instant] the instant to compare with
    # @param tolerance [Horologium::Duration] the largest gap counted as equal
    # @return [Boolean]
    # @example
    #   a = Horologium::Instant.from_tai_julian_date(2_460_000.5)
    #   b = a + Horologium::Duration.nanoseconds(1)
    #   a.equal_within?(b, Horologium::Duration.nanoseconds(2)) # => true
    def equal_within?(other, tolerance)
      unless other.is_a?(Instant)
        raise DimensionalError,
          "cannot compare an Instant with a #{other.class}"
      end
      unless tolerance.is_a?(Duration)
        raise DimensionalError,
          "a tolerance must be a Duration, got a #{tolerance.class}"
      end

      (self - other).abs <= tolerance
    end

    private

    # The duration's seconds counted in days, at the given precision. A Julian
    # Date counts days, so a duration is scaled before it is added.
    #
    # @param duration [Horologium::Duration]
    # @param precision [Symbol]
    # @return [Horologium::Numeric::TwoPartFloat, Horologium::Numeric::Exact]
    def seconds_to_days(duration, precision)
      Numeric::Precision.coerce(duration.value, to: precision) /
        Duration::SECONDS_PER_DAY
    end
  end
end
