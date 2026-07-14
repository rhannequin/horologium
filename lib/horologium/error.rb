# frozen_string_literal: true

module Horologium
  # Base class for all errors raised by Horologium. Every error the library
  # raises descends from it, so a caller can rescue Horologium as a unit.
  class Error < StandardError; end

  # Raised when the configuration is changed after it has been frozen. The
  # global default is set once, inside {Horologium.configure}, and locked
  # afterwards.
  class ConfigurationError < Error; end

  # Raised when an operation mixes quantities that do not combine, such as
  # adding two instants. Only a point plus or minus a duration, and the
  # difference of two points, are meaningful.
  class DimensionalError < Error; end

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
end
