# frozen_string_literal: true

module Horologium
  # Holds the library's settings. Today that is a single value, the default
  # precision new instants and durations take when none is asked for. It is set
  # once, inside {Horologium.configure}, and frozen afterwards, so behaviour
  # does not depend on when in the process' life an object is read.
  class Configuration
    # @return [Symbol] the default precision, +:standard+ until configured
    attr_reader :default_precision

    def initialize
      @default_precision = :standard
    end

    # Sets the default precision.
    #
    # @param precision [Symbol] +:standard+ or +:exact+
    # @return [Symbol] the precision that was set
    # @raise [ConfigurationError] once the configuration is frozen
    # @raise [UnknownPrecisionError] when the precision is not recognised
    def default_precision=(precision)
      if frozen?
        raise ConfigurationError, "the configuration is already frozen"
      end

      @default_precision = Numeric::Precision.validate!(precision)
    end
  end

  # The key under which the scoped precision is stored. Thread#[] is per-fiber,
  # so a scope entered in one fiber or thread does not affect another.
  PRECISION_SCOPE_KEY = :horologium_current_precision
  private_constant :PRECISION_SCOPE_KEY

  class << self
    # Configures the library. The yielded configuration is frozen when the
    # block returns, so it can be set once at boot and not changed again.
    #
    # @yieldparam config [Configuration] the configuration to set
    # @return [Configuration] the frozen configuration
    # @example
    #   Horologium.configure do |c|
    #     c.default_precision = :exact
    #   end
    def configure
      config = configuration
      yield config if block_given?
      config.freeze
    end

    # @return [Configuration] the current configuration, built with defaults if
    #   the library has not been configured yet
    def configuration
      @configuration ||= Configuration.new
    end

    # @return [Symbol] the configured default precision
    def default_precision
      configuration.default_precision
    end

    # The precision in effect right now: the one set by {with_precision} if a
    # scope is open, otherwise the default. This is what a constructor consults
    # when it is not given a precision of its own.
    #
    # @return [Symbol] +:standard+ or +:exact+
    def current_precision
      Thread.current[PRECISION_SCOPE_KEY] || default_precision
    end

    # Runs the block with a chosen precision in effect, then restores whatever
    # was in effect before. The scope is per-fiber, so it is safe to use in a
    # threaded or fibered context and cannot leak into other work. It does not
    # touch the frozen default.
    #
    # @param precision [Symbol] +:standard+ or +:exact+
    # @return [Object] the block's return value
    # @raise [UnknownPrecisionError] when the precision is not recognised
    # @example
    #   Horologium.with_precision(:exact) do
    #     # instants built here default to :exact
    #   end
    def with_precision(precision)
      Numeric::Precision.validate!(precision)
      previous = Thread.current[PRECISION_SCOPE_KEY]
      Thread.current[PRECISION_SCOPE_KEY] = precision
      begin
        yield
      ensure
        Thread.current[PRECISION_SCOPE_KEY] = previous
      end
    end

    # Clears the configuration and any open precision scope. Meant for test
    # isolation, so one test's configuration does not carry into another.
    #
    # @api private
    # @return [void]
    def reset_configuration!
      @configuration = nil
      Thread.current[PRECISION_SCOPE_KEY] = nil
    end
  end
end
