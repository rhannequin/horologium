# frozen_string_literal: true

module Horologium
  # Holds the library's settings: the default precision new instants and
  # durations take when none is asked for, and the time scales an instant can
  # be read in. Both are set once, inside {Horologium.configure}, and frozen
  # afterwards, so behaviour does not depend on when in the process' life an
  # object is read.
  class Configuration
    # The scales the library ships with. They are registered before the
    # library is configured.
    BUILT_IN_SCALES = {
      tai: Scales::TAI,
      tt: Scales::TT
    }.freeze

    # @return [Symbol] the default precision, +:standard+ until configured
    attr_reader :default_precision

    def initialize
      @default_precision = :standard
      @scales = BUILT_IN_SCALES.dup
    end

    # The names an instant can be read in, the built-in scales and any scale
    # {#register_scale} added.
    #
    # @return [Array<Symbol>]
    def scale_names
      @scales.keys
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

    # Registers a time scale under a name, so an instant can be read in it
    # with {Instant#to}. The scale is a class implementing {Scales::Base}: it
    # says how to read TAI in the scale, and how to read the scale back in
    # TAI. Registering a name that is already taken replaces the scale under
    # it, so a scale the library ships can be swapped for another model.
    #
    # A scale that does not implement both of them is refused here, at boot,
    # rather than when an instant is first read in it.
    #
    # @param name [Symbol] the name to read the scale under
    # @param scale [Class] a subclass of {Scales::Base}
    # @return [Class] the scale that was registered
    # @raise [ConfigurationError] once the configuration is frozen, when the
    #   name is not a Symbol, or when the scale does not implement
    #   {Scales::Base}
    # @example
    #   class MyScale < Horologium::Scales::Base
    #     # .from_reference and .to_reference
    #   end
    #
    #   Horologium.configure do |c|
    #     c.register_scale(:my_scale, MyScale)
    #   end
    def register_scale(name, scale)
      if @scales.frozen?
        raise ConfigurationError, "the configuration is already frozen"
      end

      unless name.is_a?(Symbol)
        raise ConfigurationError,
          "a scale is registered under a Symbol, got #{name.inspect}"
      end

      validate_scale!(scale)

      @scales[name] = scale
    end

    # The scale registered under a name.
    #
    # @param name [Symbol] the name of the scale, such as +:tt+
    # @return [Class] the scale
    # @raise [UnknownScaleError] when no scale is registered under that name
    def scale(name)
      @scales.fetch(name) do
        raise UnknownScaleError.new(name, scale_names)
      end
    end

    # Freezes the configuration and the scales with it, so neither changes
    # once the library is configured.
    #
    # @return [self]
    def freeze
      @scales.freeze
      super
    end

    private

    # Checks that a scale can be read in: a class implementing both halves of
    # {Scales::Base}. A subclass that inherits either one from {Scales::Base}
    # would raise NotImplementedError on the first conversion, so it is
    # refused here instead.
    #
    # @param scale [Object] the scale to check
    # @return [void]
    # @raise [ConfigurationError] when it is not a scale
    def validate_scale!(scale)
      unless scale.is_a?(Class) && scale < Scales::Base
        raise ConfigurationError,
          "a scale must be a subclass of Horologium::Scales::Base, " \
          "got #{scale.inspect}"
      end

      missing = %i[from_reference to_reference].select do |method|
        scale.method(method).owner == Scales::Base.singleton_class
      end
      return if missing.empty?

      raise ConfigurationError,
        "#{scale} does not implement #{missing.join(" or ")}"
    end
  end

  class << self
    # Configures the library. The yielded configuration is frozen when the
    # block returns, so it can be set once at boot and not changed again. It
    # is frozen even when the block raises, so a configuration that failed
    # half way through cannot be quietly finished off later.
    #
    # @yieldparam config [Configuration] the configuration to set
    # @return [Configuration] the frozen configuration
    # @example
    #   Horologium.configure do |c|
    #     c.default_precision = :exact
    #   end
    def configure
      config = configuration
      begin
        yield config if block_given?
      ensure
        config.freeze
      end
      config
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
      Thread.current[:horologium_current_precision] || default_precision
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
      previous = Thread.current[:horologium_current_precision]
      Thread.current[:horologium_current_precision] = precision
      begin
        yield
      ensure
        Thread.current[:horologium_current_precision] = previous
      end
    end

    # Clears the configuration and any open precision scope. Meant for test
    # isolation, so one test's configuration does not carry into another.
    #
    # @api private
    # @return [void]
    def reset_configuration!
      @configuration = nil
      Thread.current[:horologium_current_precision] = nil
    end
  end
end
