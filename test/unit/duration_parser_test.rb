require "test_helper"
require "rcal/duration_parser"

module Rcal
  class DurationParserTest < Minitest::Test
    def setup
      DurationParser.reset_adapter!
    end

    def teardown
      DurationParser.reset_adapter!
    end

    # Public interface delegates to adapter

    def test_parse_delegates_to_adapter
      result = DurationParser.parse("30m")

      assert_equal 1800, result
    end

    def test_parse_handles_long_format
      result = DurationParser.parse("1 hour and 30 minutes")

      assert_equal 5400, result
    end

    def test_parse_minutes_delegates_to_adapter
      result = DurationParser.parse_minutes("1h")

      assert_equal 60, result
    end

    def test_parse_raises_parse_error_for_invalid_input
      assert_raises(Rcal::ParseError) do
        DurationParser.parse("not a duration")
      end
    end

    # Adapter configuration

    def test_uses_default_adapter
      assert_instance_of Adapters::DurationParser::ChronicDuration, DurationParser.adapter
    end

    def test_allows_custom_adapter
      custom_adapter = Minitest::Mock.new
      custom_adapter.expect(:parse, 3600, ["test"])

      DurationParser.adapter = custom_adapter
      result = DurationParser.parse("test")

      assert_equal 3600, result
      custom_adapter.verify
    end

    def test_reset_adapter_restores_default
      custom_adapter = Object.new
      DurationParser.adapter = custom_adapter

      DurationParser.reset_adapter!

      assert_instance_of Adapters::DurationParser::ChronicDuration, DurationParser.adapter
    end
  end
end
