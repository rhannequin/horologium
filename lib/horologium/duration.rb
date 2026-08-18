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

    # The same length, never negative.
    #
    # @return [Horologium::Duration]
    def abs
      rational.negative? ? self.class.new(value * -1, precision) : self
    end
  end
end
