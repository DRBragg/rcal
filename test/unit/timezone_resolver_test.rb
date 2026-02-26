require "test_helper"
require "rcal/timezone_resolver"
require "rcal/models/calendar"
require "rcal/calendar_service"

module Rcal
  class TimezoneResolverTest < Minitest::Test
    def setup
      CalendarService.reset_adapter!
    end

    def teardown
      CalendarService.reset_adapter!
    end

    # resolve tests

    def test_resolve_returns_explicit_timezone_when_provided
      result = TimezoneResolver.resolve(explicit: "Europe/London", calendar_id: "primary")

      assert_equal "Europe/London", result
    end

    def test_resolve_explicit_takes_priority_over_calendar_and_system
      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:get_calendar).never
      CalendarService.adapter = mock_adapter

      result = TimezoneResolver.resolve(explicit: "Asia/Tokyo", calendar_id: "primary")

      assert_equal "Asia/Tokyo", result
    end

    def test_resolve_falls_back_to_calendar_timezone
      calendar = Rcal::Calendar.new(
        id: "primary",
        name: "My Calendar",
        timezone: "America/Chicago"
      )

      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:get_calendar).with(calendar_id: "primary").returns(calendar)
      CalendarService.adapter = mock_adapter

      result = TimezoneResolver.resolve(explicit: nil, calendar_id: "primary")

      assert_equal "America/Chicago", result
    end

    def test_resolve_falls_back_to_system_timezone_when_no_calendar
      result = TimezoneResolver.resolve(explicit: nil, calendar_id: nil)

      # Should return something — either ENV["TZ"] or a mapped abbreviation
      refute_nil result
      refute_empty result
    end

    def test_resolve_falls_back_to_system_timezone_when_calendar_fetch_fails
      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:get_calendar).raises(StandardError.new("Network error"))
      CalendarService.adapter = mock_adapter

      result = TimezoneResolver.resolve(explicit: nil, calendar_id: "primary")

      refute_nil result
      refute_empty result
    end

    # calendar_timezone tests

    def test_calendar_timezone_returns_calendar_tz
      calendar = Rcal::Calendar.new(
        id: "work@group.calendar.google.com",
        name: "Work",
        timezone: "America/New_York"
      )

      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:get_calendar)
        .with(calendar_id: "work@group.calendar.google.com")
        .returns(calendar)
      CalendarService.adapter = mock_adapter

      result = TimezoneResolver.calendar_timezone("work@group.calendar.google.com")

      assert_equal "America/New_York", result
    end

    def test_calendar_timezone_returns_nil_for_nil_calendar_id
      result = TimezoneResolver.calendar_timezone(nil)

      assert_nil result
    end

    def test_calendar_timezone_returns_nil_on_api_error
      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:get_calendar).raises(StandardError.new("Not found"))
      CalendarService.adapter = mock_adapter

      result = TimezoneResolver.calendar_timezone("nonexistent")

      assert_nil result
    end

    def test_calendar_timezone_returns_nil_when_calendar_has_no_timezone
      calendar = Rcal::Calendar.new(
        id: "primary",
        name: "My Calendar",
        timezone: nil
      )

      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:get_calendar).returns(calendar)
      CalendarService.adapter = mock_adapter

      result = TimezoneResolver.calendar_timezone("primary")

      assert_nil result
    end

    # system_timezone tests

    def test_system_timezone_uses_env_tz_when_iana_format
      original_tz = ENV["TZ"]
      begin
        ENV["TZ"] = "America/Denver"
        result = TimezoneResolver.system_timezone

        assert_equal "America/Denver", result
      ensure
        ENV["TZ"] = original_tz
      end
    end

    def test_system_timezone_ignores_non_iana_env_tz
      original_tz = ENV["TZ"]
      begin
        ENV["TZ"] = "EST"
        result = TimezoneResolver.system_timezone

        # Should not return "EST" — should map via abbreviation table or fallback
        assert_includes result, "/"
      ensure
        ENV["TZ"] = original_tz
      end
    end

    def test_system_timezone_returns_iana_string
      result = TimezoneResolver.system_timezone

      # IANA timezone strings always contain a "/"
      assert_includes result, "/"
    end

    def test_system_timezone_maps_known_abbreviations
      # Verify a few well-known mappings exist
      assert_equal "America/New_York", TimezoneResolver::ZONE_ABBREVIATIONS["EST"]
      assert_equal "America/New_York", TimezoneResolver::ZONE_ABBREVIATIONS["EDT"]
      assert_equal "America/Chicago", TimezoneResolver::ZONE_ABBREVIATIONS["CST"]
      assert_equal "America/Los_Angeles", TimezoneResolver::ZONE_ABBREVIATIONS["PST"]
      assert_equal "Etc/UTC", TimezoneResolver::ZONE_ABBREVIATIONS["UTC"]
    end
  end
end
