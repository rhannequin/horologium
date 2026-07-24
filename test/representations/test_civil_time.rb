# frozen_string_literal: true

require "test_helper"

class TestRepresentationsCivilTime < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  def test_it_is_frozen
    civil = Horologium::Representations::CivilTime.new(2025, 5, 1)

    assert_predicate civil, :frozen?
  end

  def test_it_holds_the_fields_it_was_given
    civil = Horologium::Representations::CivilTime.new(
      2025, 5, 1, 12, 34, 56, 0.5
    )

    assert_equal 2025, civil.year
    assert_equal 5, civil.month
    assert_equal 1, civil.day
    assert_equal 12, civil.hour
    assert_equal 34, civil.minute
    assert_equal 56, civil.second
    assert_in_delta 0.5, civil.second_fraction
  end

  def test_the_time_of_day_defaults_to_midnight
    civil = Horologium::Representations::CivilTime.new(2025, 5, 1)

    assert_equal 0, civil.hour
    assert_equal 0, civil.minute
    assert_equal 0, civil.second
    assert_equal 0, civil.second_fraction
  end

  def test_it_is_equal_to_another_holding_the_same_fields
    assert_equal Horologium::Representations::CivilTime.new(2025, 5, 1, 12),
      Horologium::Representations::CivilTime.new(2025, 5, 1, 12)
  end

  def test_it_is_not_equal_when_a_field_differs
    refute_equal Horologium::Representations::CivilTime.new(2025, 5, 1, 12),
      Horologium::Representations::CivilTime.new(2025, 5, 1, 13)
  end

  def test_it_compares_the_fraction_of_a_second_by_the_value_it_holds
    assert_equal Horologium::Representations::CivilTime.new(
      2025, 5, 1, 12, 0, 0, Rational(1, 2)
    ),
      Horologium::Representations::CivilTime.new(2025, 5, 1, 12, 0, 0, 0.5)
  end

  def test_a_rounded_fraction_is_not_equal_to_the_value_it_was_rounded_from
    refute_equal Horologium::Representations::CivilTime.new(
      2025, 5, 1, 12, 0, 0, Rational(1, 10)
    ),
      Horologium::Representations::CivilTime.new(2025, 5, 1, 12, 0, 0, 0.1)
  end

  def test_it_is_not_equal_to_a_value_of_another_type
    refute_equal Horologium::Representations::CivilTime.new(2025, 5, 1), :civil
  end

  def test_equal_civil_times_are_the_same_hash_key
    hash = {
      Horologium::Representations::CivilTime.new(
        2025, 5, 1, 12, 0, 0, Rational(1, 2)
      ) => :noon
    }

    assert_equal :noon,
      hash[
        Horologium::Representations::CivilTime.new(2025, 5, 1, 12, 0, 0, 0.5)
      ]
  end

  def test_it_is_eql_to_another_holding_the_same_fields
    assert_operator Horologium::Representations::CivilTime.new(2025, 5, 1),
      :eql?,
      Horologium::Representations::CivilTime.new(2025, 5, 1)
  end

  def test_it_reads_as_its_fields_in_a_console
    civil = Horologium::Representations::CivilTime.new(1977, 1, 1)

    assert_equal "#<Horologium::Representations::CivilTime 1977-01-01 " \
      "00:00:00>",
      civil.inspect
  end

  def test_a_fraction_of_a_second_shows_in_the_console
    civil =
      Horologium::Representations::CivilTime.new(1977, 1, 1, 0, 0, 32, 0.5)

    assert_equal "#<Horologium::Representations::CivilTime 1977-01-01 " \
      "00:00:32.5>",
      civil.inspect
  end

  def test_a_small_fraction_of_a_second_shows_as_digits_in_a_console
    civil = Horologium::Representations::CivilTime.new(
      1977, 1, 1, 0, 0, 32, 0.000001
    )

    assert_equal "#<Horologium::Representations::CivilTime 1977-01-01 " \
      "00:00:32.000001>",
      civil.inspect
  end

  def test_a_small_fraction_of_a_second_keeps_the_digits_under_it
    civil = Horologium::Representations::CivilTime.new(
      1977, 1, 1, 0, 0, 32, 1.2345e-07
    )

    assert_equal "#<Horologium::Representations::CivilTime 1977-01-01 " \
      "00:00:32.00000012345>",
      civil.inspect
  end
end
