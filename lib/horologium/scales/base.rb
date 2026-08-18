# frozen_string_literal: true

module Horologium
  # The time scales an instant can be read in. Every scale converts to and
  # from TAI, the scale the library stores instants in, so a conversion from
  # one scale to another goes through TAI. {Scales::Base} is what a scale
  # implements, and {Configuration#register_scale} adds one.
  module Scales
    # The two methods a time scale implements. One reads a TAI Julian Date in
    # the scale, the other reads a Julian Date in the scale back in TAI. Every
    # scale converts to and from TAI, so a scale does not need to know about
    # the other scales.
    #
    # The values are Julian Dates in days. They come at the precision of the
    # instant, a {Numeric::TwoPartFloat} at +:standard+ and a
    # {Numeric::Exact} at +:exact+. A scale keeps that precision, and builds
    # what it adds at the precision it is given.
    #
    # @abstract Implement {from_reference} and {to_reference} in a subclass.
    # @example A scale one minute ahead of TAI
    #   class MyScale < Horologium::Scales::Base
    #     OFFSET = Rational(60, 86_400)
    #
    #     class << self
    #       def from_reference(value, precision)
    #         Horologium::Numeric::Precision.add(
    #           value,
    #           Horologium::Numeric::Precision.build(OFFSET, precision)
    #         )
    #       end
    #
    #       def to_reference(value, precision)
    #         Horologium::Numeric::Precision.subtract(
    #           value,
    #           Horologium::Numeric::Precision.build(OFFSET, precision)
    #         )
    #       end
    #     end
    #   end
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
        # {from_reference}. Calling one after the other returns the value
        # given.
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

        # The SI seconds in a day of this scale, on the day at +day_number+.
        # A day is 86,400 seconds in every scale the library reads by
        # continuous time. UTC is the exception: a day that holds a leap
        # second is 86,401 seconds long, so UTC overrides this. A
        # representation asks the scale this to map a fraction of a day to a
        # time of day, and to know whether a 61-second final minute is legal.
        #
        # @param _day_number [Integer] the Julian Day Number of the day
        # @return [Integer] the seconds in that day
        def seconds_in_day(_day_number)
          Duration::SECONDS_PER_DAY
        end

        # The ISO 8601 zone designator this scale writes. Empty for a
        # continuous scale, where the string carries no scale of its own and a
        # bare time is a coordinate in the scale it was read in. UTC writes
        # +"Z"+, where a zero offset is a real thing.
        #
        # @return [String]
        def zone_designator
          ""
        end

        # A continuous scale is +:measured+ everywhere, its conversions
        # resting on constants and models rather than revised data. UTC is the
        # exception; see {UTC.provenance}.
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
