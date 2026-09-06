# frozen_string_literal: true

require "test_helper"

# An interval is a span between two instants, holding its start and excluding
# its end. Its length is elapsed SI seconds, which is what makes a window
# across a leap second a second longer than the clock suggests.
class TestInterval < Minitest::Test
  def setup
    @start = Horologium::Instant.from_utc(2025, 5, 1, precision: :exact)
    @middle = Horologium::Instant.from_utc(2025, 5, 1, 1, precision: :exact)
    @finish = Horologium::Instant.from_utc(2025, 5, 1, 2, precision: :exact)
    @window = Horologium::Interval.new(@start, @finish)
  end

  def test_it_runs_between_two_instants
    assert_equal @start, @window.start
    assert_equal @finish, @window.end
  end

  def test_its_duration_is_the_time_between_its_ends
    assert_equal Horologium::Duration.hours(2, precision: :exact),
      @window.duration
  end

  # The showcase. The clock says two hours; two hours and a second went by,
  # because a leap second was inserted inside the window.
  def test_a_window_across_a_leap_second_is_a_second_longer
    window = Horologium::Interval.parse(
      "2016-12-31T23:00Z/2017-01-01T01:00Z",
      scale: :utc,
      precision: :exact
    )

    assert_equal 7201, window.duration.in_seconds
  end

  def test_an_interval_is_built_from_a_start_and_a_length
    assert_equal @window,
      Horologium::Interval.from(
        @start,
        Horologium::Duration.hours(2, precision: :exact)
      )
  end

  def test_it_holds_its_start
    assert @window.cover?(@start)
  end

  # Half open, so one window runs into the next without the two overlapping on
  # the moment they share.
  def test_it_excludes_its_end
    refute @window.cover?(@finish)
  end

  def test_it_covers_an_instant_inside_it
    assert @window.cover?(@middle)
  end

  def test_it_covers_nothing_outside_it
    refute @window.cover?(
      Horologium::Instant.from_utc(2025, 4, 30, precision: :exact)
    )
  end

  def test_a_span_of_no_time_is_a_span_and_covers_nothing
    empty = Horologium::Interval.new(@start, @start)

    assert_predicate empty.duration, :zero?
    refute empty.cover?(@start)
  end

  def test_two_windows_that_share_time_overlap
    other = Horologium::Interval.new(
      @middle,
      Horologium::Instant.from_utc(2025, 5, 1, 3, precision: :exact)
    )

    assert @window.overlap?(other)
    assert other.overlap?(@window)
  end

  def test_two_windows_that_only_touch_do_not_overlap
    next_one = Horologium::Interval.new(
      @finish,
      Horologium::Instant.from_utc(2025, 5, 1, 3, precision: :exact)
    )

    refute @window.overlap?(next_one)
    assert_nil @window.intersection(next_one)
  end

  def test_the_intersection_of_two_windows
    other = Horologium::Interval.new(
      @middle,
      Horologium::Instant.from_utc(2025, 5, 1, 3, precision: :exact)
    )

    assert_equal Horologium::Interval.new(@middle, @finish),
      @window.intersection(other)
  end

  def test_the_intersection_of_windows_that_share_nothing_is_nothing
    assert_nil @window.intersection(
      Horologium::Interval.from(
        Horologium::Instant.from_utc(2025, 6, 1, precision: :exact),
        Horologium::Duration.hours(1)
      )
    )
  end

  def test_it_reads_an_iso_8601_interval
    assert_equal @window,
      Horologium::Interval.parse(
        "2025-05-01T00:00:00Z/2025-05-01T02:00:00Z",
        scale: :utc,
        precision: :exact
      )
  end

  def test_it_writes_an_iso_8601_interval
    assert_equal "2025-05-01T00:00:00.000000000Z/" \
      "2025-05-01T02:00:00.000000000Z",
      @window.to_iso8601(scale: :utc)
  end

  def test_a_written_interval_reads_back
    assert_equal @window,
      Horologium::Interval.parse(
        @window.to_iso8601(scale: :utc),
        scale: :utc,
        precision: :exact
      )
  end

  # Repetition is scheduling, and scheduling is not what this library is for.
  def test_a_repeating_interval_is_not_read
    assert_raises(Horologium::ParseError) do
      Horologium::Interval.parse(
        "R5/2025-05-01T00:00:00Z/2025-05-01T02:00:00Z",
        scale: :utc
      )
    end
  end

  def test_an_interval_written_as_a_start_and_a_duration_is_not_read
    assert_raises(Horologium::ParseError) do
      Horologium::Interval.parse("2025-05-01T00:00:00Z/PT2H", scale: :utc)
    end
  end

  def test_it_refuses_a_string_that_is_not_an_interval
    ["nope", "", "2025-05-01T00:00:00Z", nil, 5].each do |value|
      assert_raises(Horologium::ParseError) do
        Horologium::Interval.parse(value, scale: :utc)
      end
    end
  end

  def test_an_interval_cannot_end_before_it_starts
    assert_raises(Horologium::InvalidIntervalError) do
      Horologium::Interval.new(@finish, @start)
    end
  end

  def test_an_interval_runs_between_instants
    assert_raises(Horologium::DimensionalError) do
      Horologium::Interval.new(@start, 5)
    end
  end

  def test_it_runs_for_a_duration
    assert_raises(Horologium::DimensionalError) do
      Horologium::Interval.from(@start, @finish)
    end
  end

  def test_a_negative_duration_is_not_a_span
    assert_raises(Horologium::InvalidIntervalError) do
      Horologium::Interval.from(@start, Horologium::Duration.hours(-1))
    end
  end

  def test_it_covers_an_instant_and_nothing_else
    assert_raises(Horologium::DimensionalError) { @window.cover?(5) }
  end

  def test_it_compares_with_an_interval_and_nothing_else
    assert_raises(Horologium::DimensionalError) { @window.overlap?(5) }
  end

  def test_two_intervals_with_the_same_ends_are_equal
    assert_equal Horologium::Interval.new(@start, @finish), @window
    assert_equal 1,
      {Horologium::Interval.new(@start, @finish) => 1, @window => 2}.size
  end

  # Only where the two precisions denote the same instant. A Julian Date on a
  # half day is exact in both; a civil time converted through UTC is not, and
  # two intervals built that way are a fraction of a yoctosecond apart.
  def test_the_ends_compare_across_precisions
    ends = [2_460_796.5, 2_460_797.5]
    standard = Horologium::Interval.new(
      *ends.map { |jd| Horologium::Instant.from_julian_date(jd, scale: :tai) }
    )
    exact = Horologium::Interval.new(
      *ends.map do |jd|
        Horologium::Instant.from_julian_date(jd, scale: :tai, precision: :exact)
      end
    )

    assert_equal exact, standard
  end

  def test_an_interval_is_frozen
    assert_predicate @window, :frozen?
  end

  def test_it_says_what_it_is
    assert_includes @window.inspect, "Horologium::Interval"
  end
end
