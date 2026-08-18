# frozen_string_literal: true

module Horologium
  # Shared behaviour for the library's immutable precise values, {Instant} and
  # {Duration}. Each holds a numeric value in a fixed precision and is compared
  # by the value it denotes, across precisions.
  module PreciseValue
    include Comparable

    # The numeric value, held as a {Numeric::TwoPartFloat} or a
    # {Numeric::Exact}.
    #
    # @api private
    # @return [Horologium::Numeric::TwoPartFloat, Horologium::Numeric::Exact]
    attr_reader :value

    # The precision, set when the value was built.
    #
    # @api private
    # @return [Symbol] +:standard+ or +:exact+
    attr_reader :precision

    # Wraps a numeric value in a precision. The value must match the
    # precision: a {Numeric::Exact} for +:exact+, a {Numeric::TwoPartFloat}
    # for +:standard+.
    #
    # @api private
    # @param value [Horologium::Numeric::TwoPartFloat,
    #   Horologium::Numeric::Exact] the value
    # @param precision [Symbol] +:standard+ or +:exact+
    # @raise [UnknownPrecisionError] when the precision is not recognised
    # @raise [ArgumentError] when the value does not match the precision
    def initialize(value, precision)
      Numeric::Precision.validate_value!(value, precision)

      @value = value
      @precision = precision
      @rational = value.to_r
      freeze
    end

    # Orders by the value denoted, across precisions. The same value compares
    # equal whatever the precision, so +==+ (from Comparable) and sorting
    # ignore it.
    #
    # @param other [Object] the value to compare with
    # @return [Integer, nil] -1, 0, or 1, or nil when other is not the same
    #   kind of value
    def <=>(other)
      return unless other.is_a?(self.class)

      rational <=> other.rational
    end

    # Stricter than +==+: the precision must match too.
    #
    # @param other [Object]
    # @return [Boolean]
    def eql?(other)
      other.is_a?(self.class) &&
        precision == other.precision &&
        rational == other.rational
    end

    # @return [Integer] a hash matching {eql?}
    def hash
      [self.class, precision, rational].hash
    end

    protected

    # The value denoted, as a Rational, computed once at construction so a
    # frozen value never recomputes it for comparison.
    #
    # @api private
    # @return [Rational]
    attr_reader :rational
  end
end
