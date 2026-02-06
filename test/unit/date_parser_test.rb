require "test_helper"
require "timecop"
require "rcal/date_parser"

module Rcal
  class DateParserTest < Minitest::Test
    def setup
      @frozen_time = Time.local(2026, 1, 30, 9, 0, 0)
      Timecop.freeze(@frozen_time)
      DateParser.reset_adapter!
    end

    def teardown
      Timecop.return
      DateParser.reset_adapter!
    end

    # Public interface delegates to adapter

    def test_parse_delegates_to_adapter
      result = DateParser.parse("tomorrow")

      assert_equal Date.new(2026, 1, 31), result
    end

    def test_parse_handles_natural_language
      result = DateParser.parse("next monday")

      assert_equal Date.new(2026, 2, 2), result
    end

    def test_parse_handles_relative_shortcuts
      result = DateParser.parse("+3d")

      assert_equal Date.new(2026, 2, 2), result
    end

    def test_parse_returns_time_when_time_specified
      result = DateParser.parse("tomorrow at 3pm")

      assert_instance_of Time, result
      assert_equal Time.local(2026, 1, 31, 15, 0, 0), result
    end

    def test_parse_raises_parse_error_for_invalid_input
      assert_raises(Rcal::ParseError) do
        DateParser.parse("not a valid date")
      end
    end

    # Adapter configuration

    def test_uses_default_adapter
      assert_instance_of Adapters::DateParser::Chronic, DateParser.adapter
    end

    def test_allows_custom_adapter
      custom_adapter = Minitest::Mock.new
      custom_adapter.expect(:parse, Date.new(2026, 1, 1), ["test"])

      DateParser.adapter = custom_adapter
      result = DateParser.parse("test")

      assert_equal Date.new(2026, 1, 1), result
      custom_adapter.verify
    end

    def test_reset_adapter_restores_default
      custom_adapter = Object.new
      DateParser.adapter = custom_adapter

      DateParser.reset_adapter!

      assert_instance_of Adapters::DateParser::Chronic, DateParser.adapter
    end
  end
end
