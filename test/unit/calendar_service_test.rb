require "test_helper"
require "rcal/calendar_service"
require "rcal/models/calendar"
require "rcal/models/event"

module Rcal
  class CalendarServiceTest < Minitest::Test
    def setup
      CalendarService.reset_adapter!
    end

    def teardown
      CalendarService.reset_adapter!
    end

    def test_list_calendars_delegates_to_adapter
      calendars = [
        Calendar.new(id: "cal1", name: "Calendar 1"),
        Calendar.new(id: "cal2", name: "Calendar 2")
      ]

      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:list_calendars).returns(calendars)

      CalendarService.adapter = mock_adapter
      result = CalendarService.list_calendars

      assert_equal 2, result.length
      assert_equal "Calendar 1", result.first.name
    end

    def test_list_events_delegates_to_adapter
      time_min = Time.now
      time_max = Time.now + 86400
      events = [
        Event.new(id: "e1", summary: "Event 1", start_time: time_min)
      ]

      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:list_events).with(
        calendar_id: "primary",
        time_min: time_min,
        time_max: time_max
      ).returns(events)

      CalendarService.adapter = mock_adapter
      result = CalendarService.list_events(
        calendar_id: "primary",
        time_min: time_min,
        time_max: time_max
      )

      assert_equal 1, result.length
      assert_equal "Event 1", result.first.summary
    end

    def test_get_event_delegates_to_adapter
      event = Event.new(id: "e1", summary: "Test Event", start_time: Time.now)

      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:get_event).with(
        calendar_id: "primary",
        event_id: "e1"
      ).returns(event)

      CalendarService.adapter = mock_adapter
      result = CalendarService.get_event(calendar_id: "primary", event_id: "e1")

      assert_equal "Test Event", result.summary
    end

    def test_create_event_delegates_to_adapter
      event = Event.new(id: "new", summary: "New Event", start_time: Time.now)

      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:create_event).with(
        calendar_id: "primary",
        event: event
      ).returns(event)

      CalendarService.adapter = mock_adapter
      result = CalendarService.create_event(calendar_id: "primary", event: event)

      assert_equal "New Event", result.summary
    end

    def test_update_event_delegates_to_adapter
      event = Event.new(id: "e1", summary: "Updated Event", start_time: Time.now)

      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:update_event).with(
        calendar_id: "primary",
        event_id: "e1",
        event: event
      ).returns(event)

      CalendarService.adapter = mock_adapter
      result = CalendarService.update_event(
        calendar_id: "primary",
        event_id: "e1",
        event: event
      )

      assert_equal "Updated Event", result.summary
    end

    def test_delete_event_delegates_to_adapter
      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:delete_event).with(
        calendar_id: "primary",
        event_id: "e1"
      ).returns(true)

      CalendarService.adapter = mock_adapter
      result = CalendarService.delete_event(calendar_id: "primary", event_id: "e1")

      assert result
    end

    def test_quick_add_delegates_to_adapter
      event = Event.new(id: "quick", summary: "Quick Event", start_time: Time.now)

      mock_adapter = mock("calendar_adapter")
      mock_adapter.expects(:quick_add).with(
        calendar_id: "primary",
        text: "Meeting tomorrow at 3pm"
      ).returns(event)

      CalendarService.adapter = mock_adapter
      result = CalendarService.quick_add(
        calendar_id: "primary",
        text: "Meeting tomorrow at 3pm"
      )

      assert_equal "Quick Event", result.summary
    end

    def test_allows_custom_adapter
      custom_adapter = Object.new
      CalendarService.adapter = custom_adapter

      assert_same custom_adapter, CalendarService.adapter
    end

    def test_reset_adapter_clears_custom_adapter
      custom_adapter = Object.new
      CalendarService.adapter = custom_adapter

      CalendarService.reset_adapter!

      refute_same custom_adapter, CalendarService.adapter
    end
  end
end
