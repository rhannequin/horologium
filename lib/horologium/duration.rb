# frozen_string_literal: true

module Horologium
  # An amount of time in SI seconds, with no date and no scale attached.
  # +Duration.days(1)+ is always 86,400 SI seconds. Because of leap seconds a
  # civil day can be a second longer or shorter, so a Duration and a calendar
  # day are different things.
  #
  # A Duration is frozen. Its precision is set when it is built, from the
  # precision in effect unless you pass one. At +:standard+ it holds the
  # seconds as a {Numeric::TwoPartFloat}, at +:exact+ as a {Numeric::Exact}.
  #
  # Two durations add and subtract to give another duration, and one negates.
  # Mixing a +:standard+ and an +:exact+ operand gives an +:exact+ result.
  # Adding an Instant to a Duration raises {DimensionalError}; it is
  # {Instant#+} that shifts a point by a span.
  #
  # @example A day is a fixed number of SI seconds
  #   Horologium::Duration.days(1) == Horologium::Duration.seconds(86_400)
  #   # => true
  class Duration
    include PreciseValue

    # The number of SI seconds in a day.
    SECONDS_PER_DAY = 86_400

    # The number of nanoseconds in a second.
    NANOSECONDS_PER_SECOND = 1_000_000_000

    class << self
      # A duration of +count+ SI seconds.
      #
      # @param count [Numeric] the number of seconds
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @example
      #   Horologium::Duration.seconds(3600)
      def seconds(count, precision: Horologium.current_precision)
        from_seconds(count, precision)
      end

      # A duration of +count+ days, each of {SECONDS_PER_DAY} SI seconds. This
      # counts time and is not tied to the calendar.
      #
      # @param count [Numeric] the number of days
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @example
      #   Horologium::Duration.days(1) == Horologium::Duration.seconds(86_400)
      #   # => true
      def days(count, precision: Horologium.current_precision)
        from_seconds(count * SECONDS_PER_DAY, precision)
      end

      # A duration of +count+ nanoseconds.
      #
      # @param count [Numeric] the number of nanoseconds
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Duration]
      # @example
      #   Horologium::Duration.nanoseconds(1)
      def nanoseconds(count, precision: Horologium.current_precision)
        from_seconds(Rational(count) / NANOSECONDS_PER_SECOND, precision)
      end

      private

      # Builds a duration of +seconds+ SI seconds at the given precision. At
      # +:exact+ the seconds stay a Rational; at +:standard+ they become a
      # two-part float. Unit scaling happens on the plain input, before this.
      #
      # @param seconds [Numeric] the number of SI seconds
      # @param precision [Symbol] the precision to build
      # @return [Horologium::Duration]
      def from_seconds(seconds, precision)
        new(Numeric::Precision.build(seconds, precision), precision)
      end
    end

    # @param other [Horologium::Duration]
    # @return [Horologium::Duration]
    # @raise [DimensionalError] when given anything but a Duration
    def +(other)
      unless other.is_a?(Duration)
        raise DimensionalError,
          "cannot add a #{other.class} to a Duration; " \
          "only a Duration combines with a Duration"
      end

      precision = Numeric::Precision.resolve(self.precision, other.precision)

      self.class.new(
        Numeric::Precision.add(value, other.value),
        precision
      )
    end

    # Negative when the other is the longer of the two.
    #
    # @param other [Horologium::Duration]
    # @return [Horologium::Duration]
    # @raise [DimensionalError] when given anything but a Duration
    def -(other)
      unless other.is_a?(Duration)
        raise DimensionalError,
          "cannot subtract a #{other.class} from a Duration; " \
          "only a Duration combines with a Duration"
      end

      precision = Numeric::Precision.resolve(self.precision, other.precision)

      self.class.new(
        Numeric::Precision.subtract(value, other.value),
        precision
      )
    end

    # The same length, the other way round.
    #
    # @return [Horologium::Duration]
    def -@
      self.class.new(value * -1, precision)
    end

    # The same length, never negative.
    #
    # @return [Horologium::Duration]
    def abs
      negative? ? -self : self
    end

    # @return [Boolean]
    def zero?
      rational.zero?
    end

    # @return [Boolean]
    def negative?
      rational.negative?
    end

    # @return [Boolean]
    def positive?
      rational.positive?
    end

    # The duration in SI seconds, exactly.
    #
    # @return [Rational]
    def to_r
      rational
    end

    # The duration in SI seconds. A Float has about 15 digits, so a long
    # duration loses its small end here; use {#to_r} for the whole of it.
    #
    # @return [Float]
    def to_f
      value.to_f
    end

    # @return [String]
    def inspect
      format("#<%s %s s (%s)>", self.class, to_f, precision)
    end
  end
end
