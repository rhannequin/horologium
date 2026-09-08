# frozen_string_literal: true

module Horologium
  # A span between two instants: an observation campaign, an eclipse window, a
  # satellite pass. It is the third of the value objects, alongside {Instant},
  # the point, and {Duration}, the quantity. An interval holds its start and
  # excludes its end. An instant exactly at the end is not covered.
  #
  # @example The window across the 2016 leap second is 7,201 seconds
  #   window = Horologium::Interval.parse(
  #     "2016-12-31T23:00Z/2017-01-01T01:00Z",
  #     scale: :utc,
  #     precision: :exact
  #   )
  #
  #   window.duration.in_seconds # => (7201/1)
  class Interval
    # The separator between the two ends of an ISO 8601 interval.
    #
    # @api private
    SEPARATOR = "/"
    private_constant :SEPARATOR

    # @return [Horologium::Instant] the instant the span starts at, included
    attr_reader :start

    # @return [Horologium::Instant] the instant the span ends at, excluded
    attr_reader :end

    class << self
      # An interval of a given length, starting at an instant.
      #
      # @param start [Horologium::Instant] the instant to start at
      # @param duration [Horologium::Duration] how long it runs
      # @return [Horologium::Interval]
      # @raise [DimensionalError] when given anything but an instant and a
      #   duration. The start is checked here rather than left to the
      #   constructor, because the end is worked out from it first.
      # @raise [InvalidIntervalError] when the duration is negative
      def from(start, duration)
        unless start.is_a?(Instant)
          raise DimensionalError,
            "an interval starts at an Instant, got a #{start.class}"
        end

        unless duration.is_a?(Duration)
          raise DimensionalError,
            "an interval runs for a Duration, got a #{duration.class}"
        end

        new(start, start + duration)
      end

      # An interval read from an ISO 8601 interval, two instants separated by a
      # +/+.
      #
      # @param value [String] the interval
      # @param scale [Symbol] the scale both ends are read in
      # @param precision [Symbol] +:standard+ or +:exact+, taken from the
      #   precision in effect when omitted
      # @return [Horologium::Interval]
      # @raise [ParseError] when it is not two instants separated by a +/+
      # @raise [InvalidIntervalError] when it ends before it starts
      def parse(value, scale:, precision: Horologium.current_precision)
        refuse(value) unless value.is_a?(String)

        ends = value.split(SEPARATOR, -1)
        refuse(value) unless ends.length == 2

        new(
          read_end(ends.fetch(0), scale, precision),
          read_end(ends.fetch(1), scale, precision)
        )
      end

      private

      # One end of an interval, read in a scale.
      #
      # @param value [String] the instant
      # @param scale [Symbol] the scale to read it in
      # @param precision [Symbol] +:standard+ or +:exact+
      # @return [Horologium::Instant]
      def read_end(value, scale, precision)
        Instant.from_iso8601(value, scale: scale, precision: precision)
      end

      # @param value [Object] what could not be read
      # @raise [ParseError] always
      def refuse(value)
        raise ParseError,
          "#{value.inspect} is not an ISO 8601 interval. It reads two " \
          "instants separated by a #{SEPARATOR}, such as " \
          "2016-12-31T23:00Z/2017-01-01T01:00Z; a repeating interval or one " \
          "written as a start and a duration is not read, and Interval.from " \
          "takes a start and a duration"
      end
    end

    # @param start [Horologium::Instant] the instant to start at, included
    # @param finish [Horologium::Instant] the instant to end at, excluded
    # @raise [DimensionalError] when either end is not an instant
    # @raise [InvalidIntervalError] when it ends before it starts
    def initialize(start, finish)
      [start, finish].each do |one|
        next if one.is_a?(Instant)

        raise DimensionalError,
          "an interval runs between two Instants, got a #{one.class}"
      end

      if finish < start
        raise InvalidIntervalError,
          "an interval ends after it starts, and this one ends " \
          "#{(start - finish).in_seconds} seconds before"
      end

      @start = start
      @end = finish
      freeze
    end

    # How long the span runs, in elapsed SI seconds.
    #
    # @return [Horologium::Duration]
    def duration
      self.end - start
    end

    # Whether an instant falls in the span.
    #
    # @param instant [Horologium::Instant] the instant to place
    # @return [Boolean]
    # @raise [DimensionalError] when given anything but an instant
    def cover?(instant)
      unless instant.is_a?(Instant)
        raise DimensionalError,
          "an interval covers an Instant, got a #{instant.class}"
      end

      instant >= start && instant < self.end
    end

    # Whether two spans share any time at all.
    #
    # @param other [Horologium::Interval] the other span
    # @return [Boolean]
    # @raise [DimensionalError] when given anything but an interval
    def overlap?(other)
      validate_interval!(other)

      start < self.end &&
        other.start < other.end &&
        start < other.end &&
        other.start < self.end
    end

    # The span two spans share, or nil where they share none.
    #
    # @param other [Horologium::Interval] the other span
    # @return [Horologium::Interval, nil]
    # @raise [DimensionalError] when given anything but an interval
    def intersection(other)
      return nil unless overlap?(other)

      self.class.new(
        [start, other.start].max,
        [self.end, other.end].min
      )
    end

    # The span as an ISO 8601 interval, both ends read in a scale.
    #
    # @param scale [Symbol] the scale to write both ends in
    # @return [String]
    # @raise [UnknownScaleError] when no scale is registered under that name
    def to_iso8601(scale:)
      [start, self.end]
        .map { |one| one.as(:iso8601, scale: scale) }
        .join(SEPARATOR)
    end

    # Two spans are equal when their ends are, whatever precision each end is
    # held in.
    #
    # @param other [Object]
    # @return [Boolean]
    def ==(other)
      other.is_a?(self.class) &&
        start == other.start &&
        self.end == other.end
    end

    # Stricter than +==+: the ends must match in precision too, the way
    # {Instant#eql?} is stricter than {Instant#==}.
    #
    # @param other [Object]
    # @return [Boolean]
    def eql?(other)
      other.is_a?(self.class) &&
        start.eql?(other.start) &&
        self.end.eql?(other.end)
    end

    # @return [Integer] a hash matching {#eql?}
    def hash
      [self.class, start, self.end].hash
    end

    # @return [String]
    def inspect
      format("#<%s %s to %s>", self.class, start.inspect, self.end.inspect)
    end

    private

    def validate_interval!(other)
      return if other.is_a?(self.class)

      raise DimensionalError,
        "an interval compares with an Interval, got a #{other.class}"
    end
  end
end
