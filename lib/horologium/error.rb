# frozen_string_literal: true

module Horologium
  # Base class for all errors raised by Horologium. A caller can rescue the
  # library as a unit. The one exception is dividing a value by zero, which
  # raises Ruby's own +ZeroDivisionError+.
  class Error < StandardError; end

  # Raised when the configuration is changed after it has been frozen, or given
  # something it cannot use.
  class ConfigurationError < Error; end

  # Raised when an operation mixes quantities that don't combine, such as adding
  # two instants.
  class DimensionalError < Error; end

  # Raised when a value the library reads is not written in a shape it accepts,
  # such as a Julian Date given as a String that doesn't spell a number.
  class ParseError < Error; end

  # Raised when two instants are not a span: an interval that ends before it
  # starts.
  class InvalidIntervalError < Error; end

  # Raised when a value given where a number is expected is not one the library
  # can compute with: not a number at all, or a Float that is not finite.
  class InvalidValueError < Error; end

  # Raised when a precision the library doesn't recognise is given, to the
  # configuration or when building a value.
  class UnknownPrecisionError < Error
    # The precisions the library recognises.
    #
    # @return [Array<Symbol>]
    attr_reader :known_precisions

    # @param precision [Object] the unknown precision that was given
    # @param known_precisions [Array<Symbol>] the recognised precisions
    def initialize(precision, known_precisions)
      @known_precisions = known_precisions.dup.freeze
      super(
        "unknown precision #{precision.inspect}, " \
        "expected one of #{known_precisions.map(&:inspect).join(", ")}"
      )
    end
  end

  # Raised when a calendar date and time of day don't exist: a day the month
  # doesn't have, an hour past the end of the day, a second 60 where no leap
  # second was inserted, or a year before the calendar conversion starts.
  class InvalidCivilTimeError < Error; end

  # Raised when a moment falls outside a scale's domain of validity, such as a
  # UTC reading before 1961, where the published TAI - UTC series starts.
  class OutOfRangeError < Error; end

  # Raised when a conversion would rest on data past the point its source
  # vouches for, and the caller has asked for strict handling rather than an
  # extrapolation.
  class OutOfDataRangeError < Error; end

  # Raised when a time scale that is not registered is asked for.
  class UnknownScaleError < Error
    # The scales registered when the error was raised.
    #
    # @return [Array<Symbol>]
    attr_reader :known_scales

    # @param scale [Object] the unknown scale that was asked for
    # @param known_scales [Array<Symbol>] the registered scales
    def initialize(scale, known_scales)
      @known_scales = known_scales.dup.freeze
      super(
        "unknown scale #{scale.inspect}, " \
        "expected one of #{known_scales.map(&:inspect).join(", ")}"
      )
    end
  end

  # Raised when a representation the library doesn't have is asked for.
  class UnknownRepresentationError < Error
    # The representations the library has.
    #
    # @return [Array<Symbol>]
    attr_reader :known_representations

    # @param representation [Object] the unknown representation asked for
    # @param known_representations [Array<Symbol>] the known representations
    def initialize(representation, known_representations)
      @known_representations = known_representations.dup.freeze
      super(
        "unknown representation #{representation.inspect}, " \
        "expected one of #{known_representations.map(&:inspect).join(", ")}"
      )
    end
  end

  # Raised when a representation is asked to come out in a type it doesn't have.
  class UnknownOutputError < Error
    # The types the representation can come out as.
    #
    # @return [Array<Symbol>]
    attr_reader :known_outputs

    # @param output [Object] the unknown output type that was asked for
    # @param known_outputs [Array<Symbol>] the types it can come out as
    def initialize(output, known_outputs)
      @known_outputs = known_outputs.dup.freeze
      super(
        "unknown output #{output.inspect}, " \
        "expected one of #{known_outputs.map(&:inspect).join(", ")}"
      )
    end
  end
end
