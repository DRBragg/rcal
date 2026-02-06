require "test_helper"
require "rcal/adapters/duration_parser/chronic_duration"

module Rcal
  module Adapters
    module DurationParser
      class ChronicDurationTest < Minitest::Test
        # Short format parsing

        def test_parses_30m
          result = ChronicDuration.parse("30m")

          assert_equal 1800, result # 30 minutes in seconds
        end

        def test_parses_1h
          result = ChronicDuration.parse("1h")

          assert_equal 3600, result # 1 hour in seconds
        end

        def test_parses_2h
          result = ChronicDuration.parse("2h")

          assert_equal 7200, result
        end

        def test_parses_1h30m
          result = ChronicDuration.parse("1h30m")

          assert_equal 5400, result # 1.5 hours
        end

        def test_parses_90m
          result = ChronicDuration.parse("90m")

          assert_equal 5400, result
        end

        # Long format parsing

        def test_parses_30_minutes
          result = ChronicDuration.parse("30 minutes")

          assert_equal 1800, result
        end

        def test_parses_1_hour
          result = ChronicDuration.parse("1 hour")

          assert_equal 3600, result
        end

        def test_parses_2_hours
          result = ChronicDuration.parse("2 hours")

          assert_equal 7200, result
        end

        def test_parses_one_hour
          result = ChronicDuration.parse("one hour")

          assert_equal 3600, result
        end

        def test_parses_two_hours
          result = ChronicDuration.parse("two hours")

          assert_equal 7200, result
        end

        def test_parses_1_hour_and_30_minutes
          result = ChronicDuration.parse("1 hour and 30 minutes")

          assert_equal 5400, result
        end

        # Minutes helper method

        def test_parse_minutes_returns_minutes
          result = ChronicDuration.parse_minutes("30m")

          assert_equal 30, result
        end

        def test_parse_minutes_converts_hours
          result = ChronicDuration.parse_minutes("1h")

          assert_equal 60, result
        end

        def test_parse_minutes_handles_mixed
          result = ChronicDuration.parse_minutes("1h30m")

          assert_equal 90, result
        end

        # Error handling

        def test_raises_parse_error_for_unparseable_input
          assert_raises(Rcal::ParseError) do
            ChronicDuration.parse("not a duration")
          end
        end

        def test_raises_parse_error_for_empty_string
          assert_raises(Rcal::ParseError) do
            ChronicDuration.parse("")
          end
        end

        def test_raises_parse_error_for_nil
          assert_raises(Rcal::ParseError) do
            ChronicDuration.parse(nil)
          end
        end

        # Edge cases

        def test_handles_whitespace
          result = ChronicDuration.parse("  30m  ")

          assert_equal 1800, result
        end

        def test_case_insensitive
          result = ChronicDuration.parse("30M")

          assert_equal 1800, result
        end
      end
    end
  end
end
