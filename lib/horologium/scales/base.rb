# frozen_string_literal: true

module Horologium
  # The time scales an instant can be read in. Every scale converts to and from
  # TAI, the scale the library stores instants in. A conversion from one
  # scale to another goes through TAI. {Scales::Base} is what a scale
  # implements, and {Configuration#register_scale} adds one.
  module Scales
    # The TT Julian Date where TT, TCG and TCB were set to read the same,
    # 1977-01-01 00:00:00 TAI. The rates that separate the two coordinate
    # scales from TT are counted from here, so both {TCG} and {TCB} need it.
    # It is {Epochs::TT_TCG_TCB_ORIGIN} written as a bare TT Julian Date,
    # which a scale can hold before {Instant} is defined.
    TT_TCG_TCB_ORIGIN_JULIAN_DATE = Rational(24_431_445_003_725, 10**7)

    # The two methods a time scale implements. One reads a TAI Julian Date in
    # the scale, the other reads a Julian Date in the scale back in TAI. Every
    # scale converts to and from TAI. A scale doesn't need to know about the
    # other scales.
    #
    # @abstract Implement {from_reference} and {to_reference} in a subclass.
    class Base
      class << self
        # A TAI Julian Date, read in this scale.
        #
        # @param _value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @param _precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in this scale, in days
        # @raise [NotImplementedError] until a subclass implements it
        def from_reference(_value, _precision)
          raise NotImplementedError, "#{self} must implement .from_reference"
        end

        # A Julian Date in this scale, read back in TAI. It undoes
        # {from_reference}.
        #
        # @param _value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in this scale, in days
        # @param _precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date in TAI, in days
        # @raise [NotImplementedError] until a subclass implements it
        def to_reference(_value, _precision)
          raise NotImplementedError, "#{self} must implement .to_reference"
        end

        # The seconds the clock counts in a day of this scale, on the day at
        # +day_number+.
        #
        # @param _day_number [Integer] the Julian Day Number of the day
        # @return [Integer] the seconds in that day
        def seconds_in_day(_day_number)
          Duration::SECONDS_PER_DAY
        end

        # The SI seconds a day of this scale spans, on the day at +day_number+.
        #
        # @param day_number [Integer] the Julian Day Number of the day
        # @return [Integer, Rational] the SI seconds in that day
        def si_seconds_in_day(day_number)
          seconds_in_day(day_number)
        end

        # The ISO 8601 zone designator this scale writes.
        #
        # @return [String]
        def zone_designator
          ""
        end

        # A continuous scale is +:measured+ everywhere, its conversions resting
        # on constants and models rather than revised data.
        #
        # @param _value [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact]
        # @return [Symbol] +:measured+
        def provenance(_value)
          :measured
        end
      end
    end
  end
end
