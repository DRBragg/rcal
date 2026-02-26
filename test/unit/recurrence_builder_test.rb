require "test_helper"
require "rcal/recurrence_builder"

module Rcal
  class RecurrenceBuilderTest < Minitest::Test
    # Basic RRULE generation

    def test_builds_daily_recurrence
      result = RecurrenceBuilder.build(freq: "daily")

      assert_equal ["RRULE:FREQ=DAILY"], result
    end

    def test_builds_weekly_recurrence
      result = RecurrenceBuilder.build(freq: "weekly")

      assert_equal ["RRULE:FREQ=WEEKLY"], result
    end

    def test_builds_monthly_recurrence
      result = RecurrenceBuilder.build(freq: "monthly")

      assert_equal ["RRULE:FREQ=MONTHLY"], result
    end

    def test_builds_yearly_recurrence
      result = RecurrenceBuilder.build(freq: "yearly")

      assert_equal ["RRULE:FREQ=YEARLY"], result
    end

    def test_returns_array_of_strings
      result = RecurrenceBuilder.build(freq: "daily")

      assert_instance_of Array, result
      assert_equal 1, result.length
      assert_instance_of String, result.first
    end

    # Frequency case insensitivity

    def test_accepts_uppercase_frequency
      result = RecurrenceBuilder.build(freq: "WEEKLY")

      assert_equal ["RRULE:FREQ=WEEKLY"], result
    end

    def test_accepts_mixed_case_frequency
      result = RecurrenceBuilder.build(freq: "Weekly")

      assert_equal ["RRULE:FREQ=WEEKLY"], result
    end

    # BYDAY with various day formats

    def test_builds_with_two_letter_day_abbreviations
      result = RecurrenceBuilder.build(freq: "weekly", days: "MO,WE,FR")

      assert_equal ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"], result
    end

    def test_builds_with_three_letter_day_abbreviations
      result = RecurrenceBuilder.build(freq: "weekly", days: "Mon,Wed,Fri")

      assert_equal ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"], result
    end

    def test_builds_with_full_day_names
      result = RecurrenceBuilder.build(freq: "weekly", days: "Monday,Wednesday,Friday")

      assert_equal ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"], result
    end

    def test_builds_with_mixed_day_formats
      result = RecurrenceBuilder.build(freq: "weekly", days: "MO,Wednesday,Fri")

      assert_equal ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"], result
    end

    def test_day_names_are_case_insensitive
      result = RecurrenceBuilder.build(freq: "weekly", days: "monday,WEDNESDAY,fri")

      assert_equal ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"], result
    end

    def test_builds_with_single_day
      result = RecurrenceBuilder.build(freq: "weekly", days: "TU")

      assert_equal ["RRULE:FREQ=WEEKLY;BYDAY=TU"], result
    end

    def test_handles_spaces_around_day_names
      result = RecurrenceBuilder.build(freq: "weekly", days: "MO , WE , FR")

      assert_equal ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"], result
    end

    def test_all_seven_days
      result = RecurrenceBuilder.build(freq: "weekly", days: "SU,MO,TU,WE,TH,FR,SA")

      assert_equal ["RRULE:FREQ=WEEKLY;BYDAY=SU,MO,TU,WE,TH,FR,SA"], result
    end

    # COUNT

    def test_builds_with_count
      result = RecurrenceBuilder.build(freq: "weekly", count: 10)

      assert_equal ["RRULE:FREQ=WEEKLY;COUNT=10"], result
    end

    def test_builds_with_string_count
      result = RecurrenceBuilder.build(freq: "weekly", count: "5")

      assert_equal ["RRULE:FREQ=WEEKLY;COUNT=5"], result
    end

    # UNTIL

    def test_builds_with_until_date
      result = RecurrenceBuilder.build(freq: "weekly", until_date: "2024-12-31")

      assert_equal ["RRULE:FREQ=WEEKLY;UNTIL=20241231T235959Z"], result
    end

    # INTERVAL

    def test_builds_with_interval
      result = RecurrenceBuilder.build(freq: "weekly", interval: 2)

      assert_equal ["RRULE:FREQ=WEEKLY;INTERVAL=2"], result
    end

    def test_builds_with_string_interval
      result = RecurrenceBuilder.build(freq: "daily", interval: "3")

      assert_equal ["RRULE:FREQ=DAILY;INTERVAL=3"], result
    end

    def test_omits_interval_when_one
      result = RecurrenceBuilder.build(freq: "weekly", interval: 1)

      assert_equal ["RRULE:FREQ=WEEKLY"], result
    end

    def test_omits_interval_when_nil
      result = RecurrenceBuilder.build(freq: "weekly", interval: nil)

      assert_equal ["RRULE:FREQ=WEEKLY"], result
    end

    # Combined options

    def test_builds_with_all_options
      result = RecurrenceBuilder.build(
        freq: "weekly",
        days: "MO,WE,FR",
        count: 10,
        interval: 2
      )

      assert_equal ["RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;COUNT=10"], result
    end

    def test_builds_weekly_with_days_and_until
      result = RecurrenceBuilder.build(
        freq: "weekly",
        days: "TU,TH",
        until_date: "2025-06-30"
      )

      assert_equal ["RRULE:FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=20250630T235959Z"], result
    end

    def test_builds_biweekly_with_days
      result = RecurrenceBuilder.build(
        freq: "weekly",
        interval: 2,
        days: "MO"
      )

      assert_equal ["RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO"], result
    end

    def test_builds_monthly_with_count
      result = RecurrenceBuilder.build(freq: "monthly", count: 12)

      assert_equal ["RRULE:FREQ=MONTHLY;COUNT=12"], result
    end

    # Validation: invalid frequency

    def test_rejects_invalid_frequency
      error = assert_raises(Rcal::Error) do
        RecurrenceBuilder.build(freq: "biweekly")
      end

      assert_match(/invalid recurrence frequency/i, error.message)
      assert_match(/biweekly/i, error.message)
    end

    def test_rejects_empty_frequency
      error = assert_raises(Rcal::Error) do
        RecurrenceBuilder.build(freq: "")
      end

      assert_match(/invalid recurrence frequency/i, error.message)
    end

    # Validation: invalid days

    def test_rejects_invalid_day_name
      error = assert_raises(Rcal::Error) do
        RecurrenceBuilder.build(freq: "weekly", days: "MO,XY")
      end

      assert_match(/invalid day.*XY/i, error.message)
    end

    def test_rejects_numeric_day
      error = assert_raises(Rcal::Error) do
        RecurrenceBuilder.build(freq: "weekly", days: "1")
      end

      assert_match(/invalid day/i, error.message)
    end

    # Validation: count and until exclusivity

    def test_rejects_both_count_and_until
      error = assert_raises(Rcal::Error) do
        RecurrenceBuilder.build(freq: "weekly", count: 10, until_date: "2024-12-31")
      end

      assert_match(/cannot specify both/i, error.message)
    end

    # Validation: invalid count

    def test_rejects_zero_count
      error = assert_raises(Rcal::Error) do
        RecurrenceBuilder.build(freq: "weekly", count: 0)
      end

      assert_match(/count must be a positive integer/i, error.message)
    end

    def test_rejects_negative_count
      error = assert_raises(Rcal::Error) do
        RecurrenceBuilder.build(freq: "weekly", count: -5)
      end

      assert_match(/count must be a positive integer/i, error.message)
    end

    def test_rejects_non_numeric_count
      error = assert_raises(Rcal::Error) do
        RecurrenceBuilder.build(freq: "weekly", count: "abc")
      end

      assert_match(/count must be a positive integer/i, error.message)
    end

    # Validation: invalid interval

    def test_rejects_zero_interval
      error = assert_raises(Rcal::Error) do
        RecurrenceBuilder.build(freq: "weekly", interval: 0)
      end

      assert_match(/interval must be a positive integer/i, error.message)
    end

    def test_rejects_negative_interval
      error = assert_raises(Rcal::Error) do
        RecurrenceBuilder.build(freq: "weekly", interval: -1)
      end

      assert_match(/interval must be a positive integer/i, error.message)
    end

    # Validation: invalid until date

    def test_rejects_invalid_until_date
      error = assert_raises(Rcal::Error) do
        RecurrenceBuilder.build(freq: "weekly", until_date: "not-a-date")
      end

      assert_match(/could not parse until date/i, error.message)
    end

    # Day alias coverage

    def test_maps_all_full_day_names
      %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].each do |day|
        result = RecurrenceBuilder.build(freq: "weekly", days: day)
        rrule = result.first
        assert_match(/BYDAY=\w{2}/, rrule, "Failed to map #{day}")
      end
    end

    def test_maps_all_three_letter_abbreviations
      %w[Sun Mon Tue Wed Thu Fri Sat].each do |day|
        result = RecurrenceBuilder.build(freq: "weekly", days: day)
        rrule = result.first
        assert_match(/BYDAY=\w{2}/, rrule, "Failed to map #{day}")
      end
    end

    def test_maps_all_two_letter_abbreviations
      %w[SU MO TU WE TH FR SA].each do |day|
        result = RecurrenceBuilder.build(freq: "weekly", days: day)
        expected = "RRULE:FREQ=WEEKLY;BYDAY=#{day}"
        assert_equal [expected], result
      end
    end
  end
end
