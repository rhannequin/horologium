# frozen_string_literal: true

module Horologium
  # Base class for all errors raised by Horologium. Every error the library
  # raises descends from it, so a caller can rescue Horologium as a unit.
  class Error < StandardError; end

  # Raised when the configuration is changed after it has been frozen. The
  # global default is set once, inside {Horologium.configure}, and locked
  # afterwards.
  class ConfigurationError < Error; end

  # Raised when a precision that is not a known backend is given, either to the
  # configuration or to the numeric backend. It carries the known precisions so
  # the caller can see the valid choices.
  class UnknownPrecisionError < Error
    # The precisions the library recognises.
    #
    # @return [Array<Symbol>]
    attr_reader :known_precisions

    # @param precision [Object] the unknown precision that was given
    # @param known_precisions [Array<Symbol>] the recognised precisions
    def initialize(precision, known_precisions)
      @known_precisions = known_precisions
      super(
        "unknown precision #{precision.inspect}, " \
        "expected one of #{known_precisions.map(&:inspect).join(", ")}"
      )
    end
  end
end
