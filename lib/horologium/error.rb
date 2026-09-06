# frozen_string_literal: true

module Horologium
  # Base class for all errors raised by Horologium. Every error the library
  # raises descends from it, so a caller can rescue Horologium as a unit.
  #
  # One error is deliberately left as Ruby's own: dividing a value by zero
  # raises +ZeroDivisionError+, the way dividing a number by zero does.
  # Wrapping it would give the same condition two names and surprise a caller
  # who already knows the first one.
  class Error < StandardError; end

  # Raised when the configuration is changed after it has been frozen, or
  # given something it cannot use. The configuration is set once, inside
  # {Horologium.configure}, and locked afterwards.
  class ConfigurationError < Error; end

  # Raised when an operation mixes quantities that do not combine, such as
  # adding two instants. Only a point plus or minus a duration, and the
  # difference of two points, are meaningful.
  class DimensionalError < Error; end

  # Raised when a value the library reads is not written in a shape it
  # accepts, such as a Julian Date given as a String that does not spell a
  # number. The message says what the shape is, and shows one.
  class ParseError < Error; end

  # Raised when two instants are not a span: an interval that ends before it
  # starts. Two instants at the same moment are a span of no time, which is a
  # real one, so only the order is refused.
  class InvalidIntervalError < Error; end

  # Raised when a value given where a number is expected is not one the
  # library can compute with: not a number at all, or a Float that is not
  # finite. A String that does not spell a number raises {ParseError}
  # instead, since a String is a shape the library does read.
  class InvalidValueError < Error; end

  # Raised when a precision the library does not recognise is given, to the
  # configuration or when building a value. It carries the known precisions so
  # the caller can see the valid choices.
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

  # Raised when a calendar date and time of day do not exist: a day the month
  # does not have, an hour past the end of the day, a second 60 where no leap
  # second was inserted, or a year before the calendar conversion starts. The
  # message says which field is wrong and what it may hold.
  class InvalidCivilTimeError < Error; end

  # Raised when a moment falls outside a scale's domain of validity, such as a
  # UTC reading before 1961, where the published TAI - UTC series starts. The
  # instant itself is still a point on the timeline; it is only the label in
  # that scale that has no meaning, so the message names a scale that does
  # reach it.
  class OutOfRangeError < Error; end

  # Raised when a conversion would rest on data past the point its source
  # vouches for, and the caller has asked for strict handling rather than an
  # extrapolation. A leap second read for a date beyond the table's expiry is
  # the case: the offset is the last known one, correct until a new leap
  # second is announced, and strict mode refuses to lean on it.
  class OutOfDataRangeError < Error; end

  # Raised when a time scale that is not registered is asked for. It carries
  # the registered scales so the caller can see the valid choices.
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

  # Raised when a representation the library does not have is asked for. It
  # carries the known representations so the caller can see the valid choices.
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

  # Raised when a representation is asked to come out in a type it does not
  # have. It carries the types it does have so the caller can see the valid
  # choices.
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
