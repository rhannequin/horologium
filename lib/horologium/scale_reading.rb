# frozen_string_literal: true

module Horologium
  # An instant seen in one time scale. It is what {Instant#to} returns.
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

    # The scale that took the reading, kept so the reading can ask it
    # questions of its own.
    #
    # @api private
    # @return [Class]
    attr_reader :time_scale

    # @api private
    # @param scale [Symbol] the registered name of the scale
    # @param time_scale [Class] the scale that took the reading, which is what
    #   answers {#provenance}
    # @param value [Horologium::Numeric::TwoPartFloat,
    #   Horologium::Numeric::Exact] the Julian Date in that scale, in days
    # @param precision [Symbol] +:standard+ or +:exact+
    # @raise [InvalidValueError] when the value does not match the precision,
    #   which is how a scale that dropped the precision it was given is caught
    def initialize(scale, value, precision, time_scale)
      Numeric::Precision.validate_value!(value, precision)

      @scale = scale
      @value = value
      @precision = precision
      @time_scale = time_scale
      freeze
    end

    # How well founded the reading is.
    #
    # @return [Symbol] +:measured+ or +:extrapolated+
    def provenance
      time_scale.provenance(value)
    end

    # The reading, in the representation asked for.
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
    def as(representation, as: :float)
      REPRESENTATIONS.fetch(representation) {
        raise UnknownRepresentationError.new(
          representation,
          REPRESENTATIONS.keys
        )
      }.render(self, as)
    end

    # Same scale, same moment in it, whatever precision each carries.
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

    # @return [String]
    def inspect
      format(
        "#<%s %s JD in %s (%s, %s)>",
        self.class,
        value.to_f,
        scale,
        precision,
        provenance
      )
    end
  end
end
