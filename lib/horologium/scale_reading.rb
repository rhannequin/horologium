# frozen_string_literal: true

module Horologium
  # An instant seen in one time scale. It is what {Instant#to} returns.
  #
  # An instant is a point on the timeline and knows no scale; +to+ chooses the
  # scale it is read in, and +as+ chooses the shape it comes out in. A reading
  # is frozen, and keeps the precision of the instant it came from.
  #
  # @example
  #   instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)
  #   instant.to(:tt).as(:julian_date) # => 2443144.5003725
  class ScaleReading
    # The representations a reading can be taken as.
    REPRESENTATIONS = {
      julian_date: Representations::JulianDate,
      modified_julian_date: Representations::ModifiedJulianDate,
      civil: Representations::Civil,
      iso8601: Representations::Iso8601
    }.freeze

    # The scale the instant is read in.
    #
    # @return [Symbol] the registered name of the scale, such as +:tt+
    attr_reader :scale

    # The precision, carried over from the instant.
    #
    # @return [Symbol] +:standard+ or +:exact+
    attr_reader :precision

    # The Julian Date in this scale, in days.
    #
    # @api private
    # @return [Horologium::Numeric::TwoPartFloat, Horologium::Numeric::Exact]
    attr_reader :value

    # How well founded the reading is. +:measured+ for a reading that rests on
    # constants, models, or confirmed data; +:extrapolated+ for a UTC reading
    # past the point its leap second data vouches for, where the offset is the
    # last known one and a new leap second could overturn it.
    #
    # @return [Symbol] +:measured+ or +:extrapolated+
    attr_reader :provenance

    # @api private
    # @param scale [Symbol] the registered name of the scale
    # @param value [Horologium::Numeric::TwoPartFloat,
    #   Horologium::Numeric::Exact] the Julian Date in that scale, in days
    # @param precision [Symbol] +:standard+ or +:exact+
    # @param provenance [Symbol] +:measured+ or +:extrapolated+
    # @raise [ArgumentError] when the value does not match the precision,
    #   which is how a scale that dropped the precision it was given is caught
    def initialize(scale, value, precision, provenance = :measured)
      Numeric::Precision.validate_value!(value, precision)

      @scale = scale
      @value = value
      @precision = precision
      @provenance = provenance
      freeze
    end

    # The reading, in the representation asked for. The whole reading is
    # handed to the representation, not only the value, because a
    # representation may need the scale to render it. A civil date in UTC has
    # to ask the scale whether the day it falls in holds a leap second.
    #
    # @param representation [Symbol] one of the keys of {REPRESENTATIONS}
    # @param as [Symbol] the type to come out as, passed on to the
    #   representation; +:float+, +:rational+, or +:two_part+ for a Julian
    #   Date
    # @return [Object] the reading, in that representation
    # @raise [UnknownRepresentationError] when the representation is not one
    #   the library has
    # @raise [UnknownOutputError] when the representation does not come out in
    #   the type asked for
    # @example
    #   instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)
    #   instant.to(:tt).as(:julian_date, as: :rational)
    def as(representation, as: :float)
      REPRESENTATIONS.fetch(representation) {
        raise UnknownRepresentationError.new(
          representation,
          REPRESENTATIONS.keys
        )
      }.render(self, as)
    end

    # Same scale, same moment in it, whatever precision each carries. This is
    # how {Instant} compares.
    #
    # @param other [Object]
    # @return [Boolean]
    def ==(other)
      other.is_a?(ScaleReading) &&
        scale == other.scale &&
        value.to_r == other.value.to_r
    end

    # Stricter than +==+: the precision must match too.
    #
    # @param other [Object]
    # @return [Boolean]
    def eql?(other)
      self == other && precision == other.precision
    end

    # @return [Integer] a hash matching {#eql?}
    def hash
      [self.class, scale, precision, value.to_r].hash
    end
  end
end
