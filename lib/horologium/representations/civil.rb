# frozen_string_literal: true

module Horologium
  module Representations
    # The calendar date and time of day an instant falls on, in the scale it is
    # read in. It is the shape a person reads, where a Julian Date is the shape
    # a series takes.
    #
    # The calendar is the proleptic Gregorian one, extended backwards past its
    # 1582 introduction, with astronomical year numbering. The conversions are
    # the ones ERFA performs in +eraJd2cal+ and +eraCal2jd+, over the range
    # those routines document, from the year {MINIMUM_YEAR} on.
    #
    # The whole conversion runs in exact Rational arithmetic, at both
    # precisions: a {Numeric::TwoPartFloat} pair is already an exact Rational,
    # so nothing is lost on the way in or out, and precision only re-enters
    # when the fraction of a second is rendered in the type asked for. That
    # makes it more accurate than +eraJd2cal+, which does the same work in
    # double precision. It also makes it slower, which is the right trade here:
    # reading a civil date is a display step, where the Julian Date and the
    # Duration are the values arithmetic runs on.
    #
    # @example
    #   instant = Horologium::Instant.from_civil(2025, 5, 1, 12, scale: :tt)
    #
    #   instant.as(:civil, scale: :tt).hour   # => 12
    #   instant.as(:civil, scale: :tai).hour  # => 11
    class Civil
      # The types the fraction of a second can come out as. A Julian Date's
      # +:two_part+ is not among them: the fraction is smaller than 1, where
      # the split exists to hold a number too large for one Float.
      OUTPUTS = %i[float rational].freeze

      # The earliest year the calendar conversion covers, the range ERFA
      # documents for +eraCal2jd+. It is also where the arithmetic stays
      # honest: every intermediate is non-negative from here on, so Ruby's
      # flooring integer division agrees with the truncating division the C
      # routines are written in.
      MINIMUM_YEAR = -4799

      # Half a day, the offset between a Julian Date, which starts at noon,
      # and the day the calendar counts, which starts at midnight.
      #
      # @api private
      HALF_DAY = Rational(1, 2)
      private_constant :HALF_DAY

      # The length of each month in a common year, from January.
      #
      # @api private
      DAYS_IN_MONTH = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze
      private_constant :DAYS_IN_MONTH

      # The seconds in an hour.
      #
      # @api private
      SECONDS_PER_HOUR = 3_600
      private_constant :SECONDS_PER_HOUR

      # The seconds in a minute.
      #
      # @api private
      SECONDS_PER_MINUTE = 60
      private_constant :SECONDS_PER_MINUTE

      class << self
        # The reading, as a calendar date and a time of day.
        #
        # The date and the whole second come from the exact value, whatever the
        # precision, so they are the fields the instant really falls on. Only
        # the fraction of a second is rendered in the type asked for: a Float
        # by default, a Rational under +as: :rational+, which keeps the whole
        # of it.
        #
        # @param reading [Horologium::ScaleReading] the instant, read in a
        #   scale
        # @param output [Symbol] one of {OUTPUTS}
        # @return [Horologium::Representations::CivilTime]
        # @raise [UnknownOutputError] when the output type is not one of
        #   {OUTPUTS}
        # @example
        #   instant = Horologium::Instant.from_julian_date(
        #     2_443_144.5,
        #     scale: :tai
        #   )
        #   instant.to(:tai).as(:civil) # => 1977-01-01 00:00:00
        def render(reading, output)
          validate_output!(output)

          scale = Horologium.configuration.scale(reading.scale)
          shifted = reading.value.to_r + HALF_DAY
          day_number = shifted.floor
          # A leap second makes a UTC day 86,401 seconds long; the scale says
          # so, and every other scale answers 86,400.
          seconds_in_day = scale.seconds_in_day(day_number)
          seconds = (shifted - day_number) * seconds_in_day

          civil_at(day_number, seconds, seconds_in_day, output)
        end

        # A civil time as it was given, as a Julian Date in days, at the
        # precision asked for. This is the way in, where {render} is the way
        # out. The Julian Date is in the scale the civil time was read in; it
        # is {Instant.from_civil} that reads it back in TAI.
        #
        # Nothing is lost: the date becomes a whole number of days by integer
        # arithmetic, and the time of day an exact fraction of one. A civil
        # time is therefore an exact way to build an instant, where a Julian
        # Date given as a single Float is not.
        #
        # @param value [Horologium::Representations::CivilTime] the civil time
        # @param _low [nil] unused; a civil time has no low part
        # @param scale [Class] the scale the civil time is read in, asked how
        #   long the day is so a leap second falls in the right place
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date, in days
        # @raise [InvalidCivilTimeError] when the fields are not a real date
        #   and time
        # @raise [ArgumentError] when the value is not a
        #   {Horologium::Representations::CivilTime}
        # @raise [UnknownPrecisionError] when the precision is not recognised
        def parse(value, _low, scale, precision)
          civil = validate!(value)
          day = day_number(civil.year, civil.month, civil.day)
          seconds_in_day = scale.seconds_in_day(day)
          validate_time!(civil, seconds_in_day)

          Numeric::Precision.build(
            day - HALF_DAY + seconds_of_day(civil) / seconds_in_day,
            precision
          )
        end

        # A civil time built from the fields as a caller writes them, where
        # the whole second and the fraction under it are one number. It is what
        # {Instant.from_civil} passes to {parse}.
        #
        # @api private
        # @param year [Integer] the year, in astronomical numbering
        # @param month [Integer] the month, from 1 to 12
        # @param day [Integer] the day of the month
        # @param hour [Integer] the hour, from 0 to 23
        # @param minute [Integer] the minute, from 0 to 59
        # @param second [Integer, Float, Rational] the second, whole or with a
        #   fraction under it
        # @return [Horologium::Representations::CivilTime]
        # @raise [ArgumentError] when the second is not a number the library
        #   reads
        def from_fields(year, month, day, hour, minute, second)
          whole, fraction = split_second(second)

          CivilTime.new(year, month, day, hour, minute, whole, fraction)
        end

        private

        # The civil time at a day number and a count of seconds into that day.
        #
        # The fraction of a second is rendered first, because rendering it as a
        # Float can round it up to a whole second. When it does, the second it
        # rounds into is the second the instant is really in, so the count of
        # seconds moves up to it and the fields are read from there. Without
        # this the fields would say 12:00:00 and the fraction 1.0, which is a
        # time that does not exist.
        #
        # @param day_number [Integer] the Julian Day Number of the day
        # @param seconds [Rational] the seconds into the day
        # @param seconds_in_day [Integer] the length of the day, in seconds
        # @param output [Symbol] one of {OUTPUTS}
        # @return [Horologium::Representations::CivilTime]
        def civil_at(day_number, seconds, seconds_in_day, output)
          whole = seconds.floor
          fraction = render_fraction(seconds - whole, output)

          if fraction == 1
            whole += 1
            fraction = render_fraction(0, output)
          end

          if whole == seconds_in_day
            day_number += 1
            whole = 0
          end

          year, month, day = calendar(day_number)

          CivilTime.new(
            year,
            month,
            day,
            whole / SECONDS_PER_HOUR,
            whole % SECONDS_PER_HOUR / SECONDS_PER_MINUTE,
            whole % SECONDS_PER_MINUTE,
            fraction
          )
        end

        # The calendar date a Julian Day Number falls on, the conversion
        # +eraJd2cal+ performs. The intermediate quantities the algorithm
        # counts in have no names of their own; they are cycles of the
        # calendar, not dates.
        #
        # @param day_number [Integer] the Julian Day Number
        # @return [Array(Integer, Integer, Integer)] the year, month, and day
        def calendar(day_number)
          remainder = day_number + 68_569
          cycles = 4 * remainder / 146_097
          remainder -= (146_097 * cycles + 3) / 4
          years = 4_000 * (remainder + 1) / 1_461_001
          remainder -= 1_461 * years / 4 - 31
          months = 80 * remainder / 2_447
          day = remainder - 2_447 * months / 80
          carried = months / 11

          [
            100 * (cycles - 49) + years + carried,
            months + 2 - 12 * carried,
            day
          ]
        end

        # The Julian Day Number of a calendar date, the conversion +eraCal2jd+
        # performs. It is written so that every operand of an integer division
        # is non-negative from {MINIMUM_YEAR} on, because Ruby's division
        # floors where C's truncates, and the two disagree on negative
        # operands. Transcribing the C literally is a bug that only shows in
        # January and February.
        #
        # @param year [Integer] the year, in astronomical numbering
        # @param month [Integer] the month, from 1 to 12
        # @param day [Integer] the day of the month
        # @return [Integer] the Julian Day Number
        def day_number(year, month, day)
          early = (14 - month) / 12
          years = year + 4_800 - early
          months = month + 12 * early - 3

          day + (153 * months + 2) / 5 + 365 * years +
            years / 4 - years / 100 + years / 400 - 32_045
        end

        # The seconds into the day a civil time falls, exactly.
        #
        # @param civil [Horologium::Representations::CivilTime] the civil time
        # @return [Rational] the seconds into the day
        def seconds_of_day(civil)
          civil.hour * SECONDS_PER_HOUR +
            civil.minute * SECONDS_PER_MINUTE +
            civil.second +
            civil.second_fraction.to_r
        end

        # The fraction of a second, in the type asked for.
        #
        # @param fraction [Rational, Integer] the fraction of a second
        # @param output [Symbol] one of {OUTPUTS}
        # @return [Float, Rational, Integer]
        def render_fraction(fraction, output)
          (output == :float) ? fraction.to_f : fraction
        end

        # A second split into the whole second and the fraction under it. A
        # String is refused: a fractional second is said exactly as a Rational,
        # and reading one out of text is what a parser does with the whole
        # timestamp.
        #
        # @param second [Integer, Float, Rational] the second
        # @return [Array(Integer, Float, Rational, Integer)] the whole second
        #   and the fraction under it
        # @raise [ArgumentError] when it is not a number the library reads
        def split_second(second)
          case second
          when Integer
            [second, 0]
          when Float, Rational
            whole = second.floor
            [whole, second - whole]
          else
            raise ArgumentError,
              "a second is an Integer, a Float, or a Rational, got a " \
              "#{second.class}; pass a Rational to give a fraction of a " \
              "second exactly"
          end
        end

        # Checks that a civil time is one the library reads, and that its
        # fields make a calendar date that exists. The time of day is left to
        # {validate_time!}, which {parse} calls once it has asked the scale how
        # long the day is: whether a second 60 is legal depends on the day.
        #
        # @param civil [Horologium::Representations::CivilTime] the civil time
        # @return [Horologium::Representations::CivilTime] the same civil time
        # @raise [InvalidCivilTimeError] when the date does not exist
        # @raise [ArgumentError] when it is not a CivilTime, or a whole field
        #   is not an Integer
        def validate!(civil)
          unless civil.is_a?(CivilTime)
            raise ArgumentError,
              "a civil time is a #{CivilTime}, got a #{civil.class}; build " \
              "one with Instant.from_civil"
          end

          validate_whole_fields!(civil)
          validate_date!(civil)

          civil
        end

        # Checks that the fields a calendar and a clock count in whole units
        # are whole. A Float year or minute means the caller has the fields in
        # the wrong order or the wrong units, and rounding it would hide that.
        #
        # @param civil [Horologium::Representations::CivilTime] the civil time
        # @return [void]
        # @raise [ArgumentError] when one of them is not an Integer
        def validate_whole_fields!(civil)
          {
            "year" => civil.year,
            "month" => civil.month,
            "day" => civil.day,
            "hour" => civil.hour,
            "minute" => civil.minute,
            "second" => civil.second
          }.each do |name, value|
            next if value.is_a?(Integer)

            raise ArgumentError,
              "the #{name} of a civil time is an Integer, got a " \
              "#{value.class}"
          end
        end

        # Checks the calendar half of a civil time.
        #
        # @param civil [Horologium::Representations::CivilTime] the civil time
        # @return [void]
        # @raise [InvalidCivilTimeError] when the date does not exist
        def validate_date!(civil)
          if civil.year < MINIMUM_YEAR
            raise InvalidCivilTimeError,
              "the year #{civil.year} is before #{MINIMUM_YEAR}, where the " \
              "calendar conversion stops; the continuous scales have no such " \
              "limit, so give the instant as a Julian Date instead"
          end

          unless (1..12).cover?(civil.month)
            raise InvalidCivilTimeError,
              "#{civil.month} is not a month; a month runs from 1 to 12"
          end

          days = days_in_month(civil.year, civil.month)
          return if (1..days).cover?(civil.day)

          raise InvalidCivilTimeError,
            "#{civil.year}-#{civil.month} has #{days} days, so there is no " \
            "day #{civil.day} in it"
        end

        # Checks the clock half of a civil time, against how long the day is.
        #
        # @param civil [Horologium::Representations::CivilTime] the civil time
        # @param seconds_in_day [Integer] the seconds in the day, the scale's
        #   answer for this day: 86,401 on a day that holds a leap second
        # @return [void]
        # @raise [InvalidCivilTimeError] when the time does not exist
        def validate_time!(civil, seconds_in_day)
          unless (0..23).cover?(civil.hour)
            raise InvalidCivilTimeError,
              "#{civil.hour} is not an hour; an hour runs from 0 to 23"
          end

          unless (0..59).cover?(civil.minute)
            raise InvalidCivilTimeError,
              "#{civil.minute} is not a minute; a minute runs from 0 to 59"
          end

          validate_second!(civil, seconds_in_day)
        end

        # Checks the second of a civil time. A minute holds 60 seconds, 0 to
        # 59, except the last minute of a day that holds a leap second, which
        # holds 61 and reaches second 60. The extra second the day carries over
        # 86,400 lands there, so the top of the range comes from the day
        # length rather than being fixed.
        #
        # @param civil [Horologium::Representations::CivilTime] the civil time
        # @param seconds_in_day [Integer] the seconds in the day
        # @return [void]
        # @raise [InvalidCivilTimeError] when the second does not exist
        def validate_second!(civil, seconds_in_day)
          highest = highest_second(civil, seconds_in_day)

          unless (0..highest).cover?(civil.second)
            raise InvalidCivilTimeError, second_out_of_range(civil, highest)
          end

          return if (0...1).cover?(civil.second_fraction)

          raise InvalidCivilTimeError,
            "#{civil.second_fraction} is not a fraction of a second; it runs " \
            "from 0 up to but not including 1"
        end

        # The highest second the minute of a civil time reaches: 59, unless it
        # is the last minute of a day longer than 86,400 seconds, where the
        # leap second lands. On a 86,401-second day the last minute reaches 60.
        #
        # @param civil [Horologium::Representations::CivilTime] the civil time
        # @param seconds_in_day [Integer] the seconds in the day
        # @return [Integer] the highest legal second
        def highest_second(civil, seconds_in_day)
          return SECONDS_PER_MINUTE - 1 unless last_minute?(civil)

          SECONDS_PER_MINUTE - 1 + (seconds_in_day - Duration::SECONDS_PER_DAY)
        end

        # Whether a civil time is in the last minute of its day, the only
        # minute a leap second can fall in.
        #
        # @param civil [Horologium::Representations::CivilTime] the civil time
        # @return [Boolean]
        def last_minute?(civil)
          civil.hour == 23 && civil.minute == 59
        end

        # The message for a second outside its minute. A second 60 that the day
        # does not reach is named as the leap second it would be, since that is
        # the mistake worth explaining; anything else states the range.
        #
        # @param civil [Horologium::Representations::CivilTime] the civil time
        # @param highest [Integer] the highest second the minute reaches
        # @return [String]
        def second_out_of_range(civil, highest)
          if civil.second == 60
            "second 60 is a leap second, and this day holds none; a minute " \
            "reaches 60 only at the end of a day that does"
          else
            "#{civil.second} is not a second; this minute runs from 0 to " \
            "#{highest}"
          end
        end

        # The days in a month, in the proleptic Gregorian calendar.
        #
        # @param year [Integer] the year, in astronomical numbering
        # @param month [Integer] the month, from 1 to 12
        # @return [Integer] the days in it
        def days_in_month(year, month)
          return 29 if month == 2 && leap_year?(year)

          DAYS_IN_MONTH[month - 1]
        end

        # Whether a year holds a leap day, by the Gregorian rule, applied
        # backwards past the calendar's introduction.
        #
        # @param year [Integer] the year, in astronomical numbering
        # @return [Boolean]
        def leap_year?(year)
          (year % 4).zero? && (!(year % 100).zero? || (year % 400).zero?)
        end

        # Checks that the output type is one a civil time comes out as.
        #
        # @param output [Symbol] the output type asked for
        # @return [Symbol] the same output type
        # @raise [UnknownOutputError] when it is not one of {OUTPUTS}
        def validate_output!(output)
          return output if OUTPUTS.include?(output)

          raise UnknownOutputError.new(output, OUTPUTS)
        end
      end
    end
  end
end
