require "test_helper"
require "timecop"
require "rcal/adapters/date_parser/chronic"

module Rcal
  module Adapters
    module DateParser
      class ChronicTest < Minitest::Test
        def setup
          # Freeze time to Friday, January 30, 2026 at 9:00 AM
          @frozen_time = Time.local(2026, 1, 30, 9, 0, 0)
          Timecop.freeze(@frozen_time)
        end

        def teardown
          Timecop.return
        end

        # Natural language parsing

        def test_parses_today
          result = Chronic.parse("today")

          assert_equal Date.new(2026, 1, 30), result
        end

        def test_parses_tomorrow
          result = Chronic.parse("tomorrow")

          assert_equal Date.new(2026, 1, 31), result
        end

        def test_parses_yesterday
          result = Chronic.parse("yesterday")

          assert_equal Date.new(2026, 1, 29), result
        end

        def test_parses_next_monday
          # Jan 30, 2026 is Friday, next Monday is Feb 2
          result = Chronic.parse("next monday")

          assert_equal Date.new(2026, 2, 2), result
        end

        def test_parses_next_week
          # Chronic interprets "next week" as the middle of next week (Wednesday)
          # Jan 30, 2026 is Friday, so next Wednesday is Feb 4
          result = Chronic.parse("next week")

          assert_equal Date.new(2026, 2, 4), result
        end

        def test_parses_in_3_days
          result = Chronic.parse("in 3 days")

          assert_equal Date.new(2026, 2, 2), result
        end

        # Time parsing

        def test_parses_tomorrow_at_3pm
          result = Chronic.parse("tomorrow at 3pm")

          assert_instance_of Time, result
          assert_equal Time.local(2026, 1, 31, 15, 0, 0), result
        end

        def test_parses_next_tuesday_at_2_30pm
          # Jan 30 is Friday, next Tuesday is Feb 3
          result = Chronic.parse("next tuesday at 2:30pm")

          assert_instance_of Time, result
          assert_equal Time.local(2026, 2, 3, 14, 30, 0), result
        end

        # ISO format strings

        def test_parses_iso_date
          result = Chronic.parse("2026-03-15")

          assert_equal Date.new(2026, 3, 15), result
        end

        def test_parses_iso_datetime
          result = Chronic.parse("2026-03-15 14:30")

          assert_instance_of Time, result
          assert_equal Time.local(2026, 3, 15, 14, 30, 0), result
        end

        # Relative shortcuts (our custom additions)

        def test_parses_plus_3_as_3_days_from_now
          result = Chronic.parse("+3")

          assert_equal Date.new(2026, 2, 2), result
        end

        def test_parses_plus_3d_as_3_days_from_now
          result = Chronic.parse("+3d")

          assert_equal Date.new(2026, 2, 2), result
        end

        def test_parses_plus_1w_as_1_week_from_now
          result = Chronic.parse("+1w")

          assert_equal Date.new(2026, 2, 6), result
        end

        def test_parses_plus_2w_as_2_weeks_from_now
          result = Chronic.parse("+2w")

          assert_equal Date.new(2026, 2, 13), result
        end

        # Error handling

        def test_raises_parse_error_for_unparseable_input
          assert_raises(Rcal::ParseError) do
            Chronic.parse("not a date at all xyz123")
          end
        end

        def test_raises_parse_error_for_empty_string
          assert_raises(Rcal::ParseError) do
            Chronic.parse("")
          end
        end

        def test_raises_parse_error_for_nil
          assert_raises(Rcal::ParseError) do
            Chronic.parse(nil)
          end
        end

        # Edge cases

        def test_handles_whitespace
          result = Chronic.parse("  tomorrow  ")

          assert_equal Date.new(2026, 1, 31), result
        end

        def test_case_insensitive
          result = Chronic.parse("TOMORROW")

          assert_equal Date.new(2026, 1, 31), result
        end
      end
    end
  end
end
