# frozen_string_literal: true

require "test_helper"

class TestEpochs < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  def test_j2000_is_noon_tt_on_the_first_of_january_2000
    assert_equal Rational(2_451_545),
      Horologium::Epochs::J2000.as(
        :julian_date,
        scale: :tt,
        as: :rational
      )
  end

  def test_j2000_is_not_noon_utc_on_the_same_day
    noon_utc = Horologium::Instant.from_utc(
      2000, 1, 1, 12,
      precision: :exact
    )

    gap = noon_utc - Horologium::Epochs::J2000

    assert_equal Rational(64_184, 1000), gap.to_r
  end

  def test_j1900_is_a_julian_century_before_j2000
    assert_equal Horologium::Duration.days(36_525),
      Horologium::Epochs::J2000 - Horologium::Epochs::J1900
  end

  def test_j1900_is_noon_tt_on_the_last_day_of_1899
    assert_equal Rational(2_415_020),
      Horologium::Epochs::J1900.as(
        :julian_date,
        scale: :tt,
        as: :rational
      )
  end

  def test_gps_zero_is_midnight_utc_on_the_sixth_of_january_1980
    assert_equal Horologium::Instant.from_utc(1980, 1, 6, precision: :exact),
      Horologium::Epochs::GPS_ZERO
  end

  def test_the_unix_epoch_is_midnight_utc_on_the_first_of_january_1970
    assert_equal Horologium::Instant.from_utc(1970, 1, 1, precision: :exact),
      Horologium::Epochs::UNIX
  end

  def test_tt_tcg_tcb_origin_is_read_in_tt_where_the_rates_start
    assert_equal Rational(24_431_445_003_725, 10_000_000),
      Horologium::Epochs::TT_TCG_TCB_ORIGIN.as(
        :julian_date,
        scale: :tt,
        as: :rational
      )
  end

  def test_they_are_exact
    assert_equal :exact, Horologium::Epochs::J2000.precision
  end

  def test_they_are_frozen
    assert_predicate Horologium::Epochs::J2000, :frozen?
  end

  def test_subtracting_one_from_a_standard_instant_gives_an_exact_duration
    instant = Horologium::Instant.from_tt(
      2026, 1, 1,
      precision: :standard
    )

    assert_equal :exact, (instant - Horologium::Epochs::J2000).precision
  end

  def test_an_epoch_shifts_by_a_duration_like_any_other_instant
    assert_equal Horologium::Instant.from_tt(2000, 1, 2, 12, precision: :exact),
      Horologium::Epochs::J2000 + Horologium::Duration.days(1)
  end
end
