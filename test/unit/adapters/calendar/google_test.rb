require "test_helper"
require "google/apis/calendar_v3"
require "rcal/adapters/calendar/base"
require "rcal/adapters/calendar/google"
require "rcal/models/calendar"
require "rcal/models/event"

module Rcal
  module Adapters
    module Calendar
      class GoogleTest < Minitest::Test
        def setup
          @mock_service = mock("calendar_service")
          @adapter = Google.new(service: @mock_service)
        end

        # List Calendars Tests

        def test_list_calendars_returns_array_of_calendar_objects
          google_response = stub_calendar_list_response([
            {id: "primary", summary: "My Calendar", primary: true, access_role: "owner"},
            {id: "work@group.calendar.google.com", summary: "Work", access_role: "writer"}
          ])

          @mock_service.expects(:list_calendar_lists).returns(google_response)

          calendars = @adapter.list_calendars

          assert_equal 2, calendars.length
          assert_instance_of Rcal::Calendar, calendars.first
        end

        def test_list_calendars_maps_all_fields
          google_response = stub_calendar_list_response([
            {
              id: "calendar123",
              summary: "Test Calendar",
              description: "A test calendar",
              time_zone: "America/New_York",
              background_color: "#4285f4",
              access_role: "owner",
              primary: true,
              selected: true
            }
          ])

          @mock_service.expects(:list_calendar_lists).returns(google_response)

          calendar = @adapter.list_calendars.first

          assert_equal "calendar123", calendar.id
          assert_equal "Test Calendar", calendar.name
          assert_equal "A test calendar", calendar.description
          assert_equal "America/New_York", calendar.timezone
          assert_equal "#4285f4", calendar.color
          assert_equal "owner", calendar.access_role
          assert calendar.primary?
          assert calendar.selected?
        end

        def test_list_calendars_handles_empty_response
          google_response = stub_calendar_list_response([])

          @mock_service.expects(:list_calendar_lists).returns(google_response)

          calendars = @adapter.list_calendars

          assert_equal [], calendars
        end

        def test_list_calendars_handles_nil_items
          google_response = mock("calendar_list")
          google_response.stubs(:items).returns(nil)

          @mock_service.expects(:list_calendar_lists).returns(google_response)

          calendars = @adapter.list_calendars

          assert_equal [], calendars
        end

        # Get Calendar Tests

        def test_get_calendar_returns_calendar_object
          google_calendar = mock("calendar")
          google_calendar.stubs(:id).returns("primary")
          google_calendar.stubs(:summary).returns("My Calendar")
          google_calendar.stubs(:description).returns("Personal calendar")
          google_calendar.stubs(:time_zone).returns("America/New_York")
          google_calendar.stubs(:background_color).returns("#4285f4")
          google_calendar.stubs(:access_role).returns("owner")
          google_calendar.stubs(:primary).returns(true)
          google_calendar.stubs(:selected).returns(true)

          @mock_service.expects(:get_calendar).with("primary").returns(google_calendar)

          calendar = @adapter.get_calendar(calendar_id: "primary")

          assert_instance_of Rcal::Calendar, calendar
          assert_equal "primary", calendar.id
          assert_equal "My Calendar", calendar.name
          assert_equal "America/New_York", calendar.timezone
        end

        def test_get_calendar_maps_all_fields
          google_calendar = mock("calendar")
          google_calendar.stubs(:id).returns("work@group.calendar.google.com")
          google_calendar.stubs(:summary).returns("Work")
          google_calendar.stubs(:description).returns("Work calendar")
          google_calendar.stubs(:time_zone).returns("America/Chicago")
          google_calendar.stubs(:background_color).returns("#0b8043")
          google_calendar.stubs(:access_role).returns("writer")
          google_calendar.stubs(:primary).returns(false)
          google_calendar.stubs(:selected).returns(true)

          @mock_service.expects(:get_calendar)
            .with("work@group.calendar.google.com")
            .returns(google_calendar)

          calendar = @adapter.get_calendar(calendar_id: "work@group.calendar.google.com")

          assert_equal "Work", calendar.name
          assert_equal "Work calendar", calendar.description
          assert_equal "America/Chicago", calendar.timezone
          assert_equal "#0b8043", calendar.color
          assert_equal "writer", calendar.access_role
          refute calendar.primary?
          assert calendar.selected?
        end

        # List Events Tests

        def test_list_events_returns_array_of_event_objects
          google_response = stub_events_response([
            {id: "event1", summary: "Meeting 1"},
            {id: "event2", summary: "Meeting 2"}
          ])

          @mock_service.expects(:list_events)
            .with("primary", has_entries(time_min: anything, time_max: anything))
            .returns(google_response)

          events = @adapter.list_events(
            calendar_id: "primary",
            time_min: Time.now,
            time_max: Time.now + 86400
          )

          assert_equal 2, events.length
          assert_instance_of Rcal::Event, events.first
        end

        def test_list_events_maps_timed_event_fields
          start_time = Time.new(2024, 1, 15, 10, 0, 0)
          end_time = Time.new(2024, 1, 15, 11, 0, 0)

          google_response = stub_events_response([
            {
              id: "event123",
              summary: "Team Standup",
              description: "Daily sync",
              location: "Conference Room A",
              start: {date_time: start_time.iso8601, time_zone: "America/New_York"},
              end: {date_time: end_time.iso8601, time_zone: "America/New_York"},
              transparency: "opaque",
              recurrence: ["RRULE:FREQ=DAILY"],
              attendees: [
                {email: "me@example.com", response_status: "accepted", self: true},
                {email: "other@example.com", response_status: "needsAction"}
              ]
            }
          ])

          @mock_service.expects(:list_events).returns(google_response)

          event = @adapter.list_events(
            calendar_id: "primary",
            time_min: start_time - 3600,
            time_max: end_time + 3600
          ).first

          assert_equal "event123", event.id
          assert_equal "Team Standup", event.summary
          assert_equal "Daily sync", event.description
          assert_equal "Conference Room A", event.location
          assert_equal start_time.to_i, event.start_time.to_i
          assert_equal end_time.to_i, event.end_time.to_i
          assert_equal "opaque", event.transparency
          assert_equal ["RRULE:FREQ=DAILY"], event.recurrence
          assert_equal 2, event.attendees.length
        end

        def test_list_events_maps_all_day_events
          google_response = stub_events_response([
            {
              id: "allday1",
              summary: "Vacation",
              start: {date: "2024-01-15"},
              end: {date: "2024-01-16"}
            }
          ])

          @mock_service.expects(:list_events).returns(google_response)

          event = @adapter.list_events(
            calendar_id: "primary",
            time_min: Time.new(2024, 1, 14),
            time_max: Time.new(2024, 1, 17)
          ).first

          assert event.all_day?
          assert_equal "Vacation", event.summary
        end

        def test_list_events_all_day_event_has_correct_time_values
          google_response = stub_events_response([
            {
              id: "allday1",
              summary: "Vacation",
              start: {date: "2024-01-15"},
              end: {date: "2024-01-16"}
            }
          ])

          @mock_service.expects(:list_events).returns(google_response)

          event = @adapter.list_events(
            calendar_id: "primary",
            time_min: Time.new(2024, 1, 14),
            time_max: Time.new(2024, 1, 17)
          ).first

          assert_instance_of Time, event.start_time
          assert_instance_of Time, event.end_time
          assert_equal Date.new(2024, 1, 15), event.start_time.to_date
          assert_equal Date.new(2024, 1, 16), event.end_time.to_date
        end

        def test_list_events_handles_mixed_timed_and_all_day_events
          google_response = stub_events_response([
            {
              id: "allday1",
              summary: "Company Holiday",
              start: {date: "2024-01-15"},
              end: {date: "2024-01-16"}
            },
            {
              id: "timed1",
              summary: "Morning Standup",
              start: {date_time: "2024-01-15T09:00:00-05:00", time_zone: "America/New_York"},
              end: {date_time: "2024-01-15T09:30:00-05:00", time_zone: "America/New_York"}
            }
          ])

          @mock_service.expects(:list_events).returns(google_response)

          events = @adapter.list_events(
            calendar_id: "primary",
            time_min: Time.new(2024, 1, 14),
            time_max: Time.new(2024, 1, 17)
          )

          assert_equal 2, events.length

          all_day_event = events.find { |e| e.id == "allday1" }
          timed_event = events.find { |e| e.id == "timed1" }

          assert all_day_event.all_day?
          refute timed_event.all_day?

          assert_instance_of Time, all_day_event.start_time
          assert_instance_of Time, timed_event.start_time
        end

        def test_list_events_extracts_self_response_status
          google_response = stub_events_response([
            {
              id: "event1",
              summary: "Meeting",
              start: {date_time: Time.now.iso8601},
              end: {date_time: (Time.now + 3600).iso8601},
              attendees: [
                {email: "me@example.com", response_status: "accepted", self: true},
                {email: "other@example.com", response_status: "declined"}
              ]
            }
          ])

          @mock_service.expects(:list_events).returns(google_response)

          event = @adapter.list_events(
            calendar_id: "primary",
            time_min: Time.now - 3600,
            time_max: Time.now + 7200
          ).first

          assert_equal "accepted", event.response_status
          assert event.accepted?
        end

        def test_list_events_handles_recurring_event_id
          google_response = stub_events_response([
            {
              id: "instance_123",
              summary: "Recurring Meeting",
              start: {date_time: Time.now.iso8601},
              end: {date_time: (Time.now + 3600).iso8601},
              recurring_event_id: "parent_event_456"
            }
          ])

          @mock_service.expects(:list_events).returns(google_response)

          event = @adapter.list_events(
            calendar_id: "primary",
            time_min: Time.now - 3600,
            time_max: Time.now + 7200
          ).first

          assert_equal "parent_event_456", event.recurring_event_id
          assert event.recurring?
        end

        def test_list_events_passes_single_events_true
          google_response = stub_events_response([])

          @mock_service.expects(:list_events)
            .with("primary", has_entry(single_events: true))
            .returns(google_response)

          @adapter.list_events(
            calendar_id: "primary",
            time_min: Time.now,
            time_max: Time.now + 86400
          )
        end

        def test_list_events_orders_by_start_time
          google_response = stub_events_response([])

          @mock_service.expects(:list_events)
            .with("primary", has_entry(order_by: "startTime"))
            .returns(google_response)

          @adapter.list_events(
            calendar_id: "primary",
            time_min: Time.now,
            time_max: Time.now + 86400
          )
        end

        def test_list_events_handles_empty_response
          google_response = stub_events_response([])

          @mock_service.expects(:list_events).returns(google_response)

          events = @adapter.list_events(
            calendar_id: "primary",
            time_min: Time.now,
            time_max: Time.now + 86400
          )

          assert_equal [], events
        end

        def test_list_events_handles_nil_items
          google_response = mock("events_list")
          google_response.stubs(:items).returns(nil)

          @mock_service.expects(:list_events).returns(google_response)

          events = @adapter.list_events(
            calendar_id: "primary",
            time_min: Time.now,
            time_max: Time.now + 86400
          )

          assert_equal [], events
        end

        def test_list_events_includes_calendar_id_on_events
          google_response = stub_events_response([
            {id: "event1", summary: "Meeting"}
          ])

          @mock_service.expects(:list_events).returns(google_response)

          event = @adapter.list_events(
            calendar_id: "work@group.calendar.google.com",
            time_min: Time.now,
            time_max: Time.now + 86400
          ).first

          assert_equal "work@group.calendar.google.com", event.calendar_id
        end

        # Quick Add Tests

        def test_quick_add_calls_service_with_text
          created_event = stub_single_event(
            id: "quick123",
            summary: "Lunch with Sarah tomorrow noon"
          )

          @mock_service.expects(:quick_add_event)
            .with("primary", "Lunch with Sarah tomorrow noon")
            .returns(created_event)

          event = @adapter.quick_add(
            calendar_id: "primary",
            text: "Lunch with Sarah tomorrow noon"
          )

          assert_instance_of Rcal::Event, event
          assert_equal "quick123", event.id
          assert_equal "Lunch with Sarah tomorrow noon", event.summary
        end

        def test_quick_add_uses_specified_calendar
          created_event = stub_single_event(id: "event1", summary: "Meeting")

          @mock_service.expects(:quick_add_event)
            .with("work@group.calendar.google.com", anything)
            .returns(created_event)

          @adapter.quick_add(
            calendar_id: "work@group.calendar.google.com",
            text: "Meeting tomorrow"
          )
        end

        # Create Event Tests

        def test_create_event_sends_event_to_service
          input_event = Rcal::Event.new(
            summary: "Team Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0),
            description: "Weekly sync",
            location: "Conference Room A"
          )

          created_event = stub_single_event(
            id: "created123",
            summary: "Team Meeting",
            description: "Weekly sync",
            location: "Conference Room A",
            start: {date_time: "2024-01-15T10:00:00"},
            end: {date_time: "2024-01-15T11:00:00"}
          )

          @mock_service.expects(:insert_event)
            .with("primary", anything)
            .returns(created_event)

          result = @adapter.create_event(calendar_id: "primary", event: input_event)

          assert_instance_of Rcal::Event, result
          assert_equal "created123", result.id
          assert_equal "Team Meeting", result.summary
        end

        def test_create_event_builds_google_event_with_all_fields
          input_event = Rcal::Event.new(
            summary: "Important Meeting",
            start_time: Time.new(2024, 1, 15, 14, 0, 0),
            end_time: Time.new(2024, 1, 15, 15, 30, 0),
            description: "Discuss quarterly goals",
            location: "Room 101"
          )

          created_event = stub_single_event(id: "new1", summary: "Important Meeting")

          @mock_service.expects(:insert_event).with("primary", anything) do |_cal_id, google_event|
            assert_equal "Important Meeting", google_event.summary
            assert_equal "Discuss quarterly goals", google_event.description
            assert_equal "Room 101", google_event.location
            assert google_event.start.date_time.start_with?("2024-01-15T14:00:00")
            assert google_event.end.date_time.start_with?("2024-01-15T15:30:00")
            true
          end.returns(created_event)

          @adapter.create_event(calendar_id: "primary", event: input_event)
        end

        def test_create_event_handles_all_day_event
          input_event = Rcal::Event.new(
            summary: "Vacation",
            start_time: Date.new(2024, 1, 15).to_time,
            end_time: Date.new(2024, 1, 16).to_time,
            all_day: true
          )

          created_event = stub_single_event(
            id: "allday1",
            summary: "Vacation",
            start: {date: "2024-01-15"},
            end: {date: "2024-01-16"}
          )

          @mock_service.expects(:insert_event).with("primary", anything) do |_cal_id, google_event|
            assert_equal "2024-01-15", google_event.start.date
            assert_equal "2024-01-16", google_event.end.date
            assert_nil google_event.start.date_time
            assert_nil google_event.end.date_time
            true
          end.returns(created_event)

          result = @adapter.create_event(calendar_id: "primary", event: input_event)

          assert result.all_day?
        end

        # Update Event Tests

        def test_update_event_sends_to_service
          input_event = Rcal::Event.new(
            id: "existing123",
            summary: "Updated Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0)
          )

          updated_event = stub_single_event(
            id: "existing123",
            summary: "Updated Meeting"
          )

          @mock_service.expects(:update_event)
            .with("primary", "existing123", anything)
            .returns(updated_event)

          result = @adapter.update_event(
            calendar_id: "primary",
            event_id: "existing123",
            event: input_event
          )

          assert_instance_of Rcal::Event, result
          assert_equal "existing123", result.id
          assert_equal "Updated Meeting", result.summary
        end

        # Transparency Tests

        def test_create_event_sets_transparency
          input_event = Rcal::Event.new(
            summary: "Focus Time",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 12, 0, 0),
            transparency: "transparent"
          )

          created_event = stub_single_event(
            id: "new1",
            summary: "Focus Time",
            transparency: "transparent"
          )

          @mock_service.expects(:insert_event).with("primary", anything) do |_cal_id, google_event|
            assert_equal "transparent", google_event.transparency
            true
          end.returns(created_event)

          result = @adapter.create_event(calendar_id: "primary", event: input_event)

          assert_equal "transparent", result.transparency
        end

        def test_create_event_transparency_nil_when_not_set
          input_event = Rcal::Event.new(
            summary: "Regular Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0)
          )

          created_event = stub_single_event(id: "new1", summary: "Regular Meeting")

          @mock_service.expects(:insert_event).with("primary", anything) do |_cal_id, google_event|
            assert_nil google_event.transparency
            true
          end.returns(created_event)

          @adapter.create_event(calendar_id: "primary", event: input_event)
        end

        def test_update_event_sets_transparency
          input_event = Rcal::Event.new(
            id: "existing123",
            summary: "Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0),
            transparency: "opaque"
          )

          updated_event = stub_single_event(
            id: "existing123",
            summary: "Meeting",
            transparency: "opaque"
          )

          @mock_service.expects(:update_event).with("primary", "existing123", anything) do |_cal, _id, google_event|
            assert_equal "opaque", google_event.transparency
            true
          end.returns(updated_event)

          result = @adapter.update_event(
            calendar_id: "primary",
            event_id: "existing123",
            event: input_event
          )

          assert_equal "opaque", result.transparency
        end

        # Delete Event Tests

        def test_delete_event_calls_service
          @mock_service.expects(:delete_event)
            .with("primary", "event_to_delete")
            .returns(nil)

          result = @adapter.delete_event(
            calendar_id: "primary",
            event_id: "event_to_delete"
          )

          assert result
        end

        # Get Event Tests

        def test_get_event_returns_single_event
          google_event = stub_single_event(
            id: "event123",
            summary: "Specific Meeting",
            description: "Details here",
            start: {date_time: Time.new(2024, 1, 15, 10, 0, 0).iso8601},
            end: {date_time: Time.new(2024, 1, 15, 11, 0, 0).iso8601}
          )

          @mock_service.expects(:get_event)
            .with("primary", "event123")
            .returns(google_event)

          event = @adapter.get_event(calendar_id: "primary", event_id: "event123")

          assert_instance_of Rcal::Event, event
          assert_equal "event123", event.id
          assert_equal "Specific Meeting", event.summary
        end

        # Time conversion tests

        def test_list_events_converts_time_to_rfc3339
          time_min = Time.new(2024, 1, 15, 9, 0, 0, "-05:00")
          time_max = Time.new(2024, 1, 15, 17, 0, 0, "-05:00")

          google_response = stub_events_response([])

          @mock_service.expects(:list_events)
            .with("primary", has_entries(
              time_min: time_min.iso8601,
              time_max: time_max.iso8601
            ))
            .returns(google_response)

          @adapter.list_events(
            calendar_id: "primary",
            time_min: time_min,
            time_max: time_max
          )
        end

        # Recurrence tests

        def test_create_event_sets_recurrence
          input_event = Rcal::Event.new(
            summary: "Weekly Standup",
            start_time: Time.new(2024, 1, 15, 9, 0, 0),
            end_time: Time.new(2024, 1, 15, 9, 30, 0),
            recurrence: ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"],
            timezone: "America/New_York"
          )

          created_event = stub_single_event(
            id: "recurring1",
            summary: "Weekly Standup",
            recurrence: ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"]
          )

          @mock_service.expects(:insert_event).with("primary", anything) do |_cal_id, google_event|
            assert_equal ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"], google_event.recurrence
            true
          end.returns(created_event)

          result = @adapter.create_event(calendar_id: "primary", event: input_event)

          assert_equal ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"], result.recurrence
        end

        def test_create_event_recurrence_nil_when_not_set
          input_event = Rcal::Event.new(
            summary: "One-off Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0)
          )

          created_event = stub_single_event(id: "new1", summary: "One-off Meeting")

          @mock_service.expects(:insert_event).with("primary", anything) do |_cal_id, google_event|
            assert_nil google_event.recurrence
            true
          end.returns(created_event)

          @adapter.create_event(calendar_id: "primary", event: input_event)
        end

        def test_update_event_sets_recurrence
          input_event = Rcal::Event.new(
            id: "existing123",
            summary: "Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0),
            recurrence: ["RRULE:FREQ=DAILY;COUNT=5"],
            timezone: "America/New_York"
          )

          updated_event = stub_single_event(id: "existing123", summary: "Meeting")

          @mock_service.expects(:update_event).with("primary", "existing123", anything) do |_cal, _id, google_event|
            assert_equal ["RRULE:FREQ=DAILY;COUNT=5"], google_event.recurrence
            true
          end.returns(updated_event)

          @adapter.update_event(
            calendar_id: "primary",
            event_id: "existing123",
            event: input_event
          )
        end

        def test_update_event_clears_recurrence_with_nil
          input_event = Rcal::Event.new(
            id: "existing123",
            summary: "Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0),
            recurrence: nil
          )

          updated_event = stub_single_event(id: "existing123", summary: "Meeting")

          @mock_service.expects(:update_event).with("primary", "existing123", anything) do |_cal, _id, google_event|
            assert_nil google_event.recurrence
            true
          end.returns(updated_event)

          @adapter.update_event(
            calendar_id: "primary",
            event_id: "existing123",
            event: input_event
          )
        end

        # Timezone tests

        def test_create_event_sets_timezone_on_timed_event
          input_event = Rcal::Event.new(
            summary: "Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0),
            timezone: "America/New_York"
          )

          created_event = stub_single_event(id: "new1", summary: "Meeting")

          @mock_service.expects(:insert_event).with("primary", anything) do |_cal_id, google_event|
            assert_equal "America/New_York", google_event.start.time_zone
            assert_equal "America/New_York", google_event.end.time_zone
            true
          end.returns(created_event)

          @adapter.create_event(calendar_id: "primary", event: input_event)
        end

        def test_create_event_sets_timezone_on_all_day_event
          input_event = Rcal::Event.new(
            summary: "Vacation",
            start_time: Date.new(2024, 1, 15).to_time,
            end_time: Date.new(2024, 1, 16).to_time,
            all_day: true,
            timezone: "America/Chicago"
          )

          created_event = stub_single_event(
            id: "allday1",
            summary: "Vacation",
            start: {date: "2024-01-15"},
            end: {date: "2024-01-16"}
          )

          @mock_service.expects(:insert_event).with("primary", anything) do |_cal_id, google_event|
            assert_equal "America/Chicago", google_event.start.time_zone
            assert_equal "America/Chicago", google_event.end.time_zone
            true
          end.returns(created_event)

          @adapter.create_event(calendar_id: "primary", event: input_event)
        end

        def test_create_event_timezone_nil_when_not_set
          input_event = Rcal::Event.new(
            summary: "Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0)
          )

          created_event = stub_single_event(id: "new1", summary: "Meeting")

          @mock_service.expects(:insert_event).with("primary", anything) do |_cal_id, google_event|
            assert_nil google_event.start.time_zone
            assert_nil google_event.end.time_zone
            true
          end.returns(created_event)

          @adapter.create_event(calendar_id: "primary", event: input_event)
        end

        def test_update_event_sets_timezone
          input_event = Rcal::Event.new(
            id: "existing123",
            summary: "Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0),
            timezone: "Europe/London"
          )

          updated_event = stub_single_event(id: "existing123", summary: "Meeting")

          @mock_service.expects(:update_event).with("primary", "existing123", anything) do |_cal, _id, google_event|
            assert_equal "Europe/London", google_event.start.time_zone
            assert_equal "Europe/London", google_event.end.time_zone
            true
          end.returns(updated_event)

          @adapter.update_event(
            calendar_id: "primary",
            event_id: "existing123",
            event: input_event
          )
        end

        # Color ID tests

        def test_list_events_maps_color_id
          google_response = stub_events_response([
            {
              id: "event1",
              summary: "Important Meeting",
              start: {date_time: Time.new(2024, 1, 15, 10, 0, 0).iso8601},
              end: {date_time: Time.new(2024, 1, 15, 11, 0, 0).iso8601},
              color_id: "11"
            }
          ])

          @mock_service.expects(:list_events).returns(google_response)

          event = @adapter.list_events(
            calendar_id: "primary",
            time_min: Time.new(2024, 1, 14),
            time_max: Time.new(2024, 1, 17)
          ).first

          assert_equal "11", event.color_id
        end

        def test_list_events_color_id_nil_when_unset
          google_response = stub_events_response([
            {
              id: "event1",
              summary: "Plain Meeting",
              start: {date_time: Time.new(2024, 1, 15, 10, 0, 0).iso8601},
              end: {date_time: Time.new(2024, 1, 15, 11, 0, 0).iso8601}
            }
          ])

          @mock_service.expects(:list_events).returns(google_response)

          event = @adapter.list_events(
            calendar_id: "primary",
            time_min: Time.new(2024, 1, 14),
            time_max: Time.new(2024, 1, 17)
          ).first

          assert_nil event.color_id
        end

        def test_create_event_sets_color_id
          input_event = Rcal::Event.new(
            summary: "Important Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0),
            color_id: "11"
          )

          created_event = stub_single_event(
            id: "new1",
            summary: "Important Meeting",
            color_id: "11"
          )

          @mock_service.expects(:insert_event).with("primary", anything) do |_cal_id, google_event|
            assert_equal "11", google_event.color_id
            true
          end.returns(created_event)

          result = @adapter.create_event(calendar_id: "primary", event: input_event)

          assert_equal "11", result.color_id
        end

        def test_create_event_omits_color_id_when_nil
          input_event = Rcal::Event.new(
            summary: "Plain Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0)
          )

          created_event = stub_single_event(id: "new1", summary: "Plain Meeting")

          @mock_service.expects(:insert_event).with("primary", anything) do |_cal_id, google_event|
            assert_nil google_event.color_id
            true
          end.returns(created_event)

          @adapter.create_event(calendar_id: "primary", event: input_event)
        end

        def test_update_event_sets_color_id
          input_event = Rcal::Event.new(
            id: "existing123",
            summary: "Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0),
            color_id: "7"
          )

          updated_event = stub_single_event(
            id: "existing123",
            summary: "Meeting",
            color_id: "7"
          )

          @mock_service.expects(:update_event).with("primary", "existing123", anything) do |_cal, _id, google_event|
            assert_equal "7", google_event.color_id
            true
          end.returns(updated_event)

          result = @adapter.update_event(
            calendar_id: "primary",
            event_id: "existing123",
            event: input_event
          )

          assert_equal "7", result.color_id
        end

        # Auth Error Handling Tests

        def test_list_calendars_raises_abort_on_google_auth_error
          @mock_service.expects(:list_calendar_lists)
            .raises(::Google::Apis::AuthorizationError.new("unauthorized"))

          error = assert_raises(CLI::Kit::Abort) { @adapter.list_calendars }
          assert_match(/Authentication expired or revoked/, error.message)
          assert_match(/rcal init/, error.message)
        end

        def test_list_events_raises_abort_on_signet_auth_error
          @mock_service.expects(:list_events)
            .raises(Signet::AuthorizationError.new("Token has been revoked"))

          error = assert_raises(CLI::Kit::Abort) do
            @adapter.list_events(
              calendar_id: "primary",
              time_min: Time.now,
              time_max: Time.now + 86400
            )
          end
          assert_match(/Authentication expired or revoked/, error.message)
        end

        def test_create_event_raises_abort_on_auth_error
          input_event = Rcal::Event.new(
            summary: "Meeting",
            start_time: Time.now,
            end_time: Time.now + 3600
          )

          @mock_service.expects(:insert_event)
            .raises(::Google::Apis::AuthorizationError.new("unauthorized"))

          error = assert_raises(CLI::Kit::Abort) do
            @adapter.create_event(calendar_id: "primary", event: input_event)
          end
          assert_match(/rcal init/, error.message)
        end

        def test_delete_event_raises_abort_on_auth_error
          @mock_service.expects(:delete_event)
            .raises(Signet::AuthorizationError.new("revoked"))

          error = assert_raises(CLI::Kit::Abort) do
            @adapter.delete_event(calendar_id: "primary", event_id: "event1")
          end
          assert_match(/rcal init/, error.message)
        end

        def test_quick_add_raises_abort_on_auth_error
          @mock_service.expects(:quick_add_event)
            .raises(::Google::Apis::AuthorizationError.new("unauthorized"))

          error = assert_raises(CLI::Kit::Abort) do
            @adapter.quick_add(calendar_id: "primary", text: "Meeting tomorrow")
          end
          assert_match(/rcal init/, error.message)
        end

        private

        def stub_calendar_list_response(calendars)
          items = calendars.map do |cal|
            item = mock("calendar_entry")
            item.stubs(:id).returns(cal[:id])
            item.stubs(:summary).returns(cal[:summary])
            item.stubs(:description).returns(cal[:description])
            item.stubs(:time_zone).returns(cal[:time_zone])
            item.stubs(:background_color).returns(cal[:background_color])
            item.stubs(:access_role).returns(cal[:access_role])
            item.stubs(:primary).returns(cal[:primary])
            item.stubs(:selected).returns(cal[:selected])
            item
          end

          response = mock("calendar_list")
          response.stubs(:items).returns(items)
          response
        end

        # Converts a date string to a Date object to match the Google API gem's
        # deserialization behavior (property :date, type: Date).
        def coerce_date(value)
          value.is_a?(String) ? Date.parse(value) : value
        end

        def stub_event_time_obj(name, data)
          obj = mock(name)
          if data
            obj.stubs(:date_time).returns(data[:date_time] ? Time.parse(data[:date_time]) : nil)
            obj.stubs(:date).returns(data[:date] ? coerce_date(data[:date]) : nil)
            obj.stubs(:time_zone).returns(data[:time_zone])
          else
            obj.stubs(:date_time).returns(Time.now)
            obj.stubs(:date).returns(nil)
            obj.stubs(:time_zone).returns(nil)
          end
          obj
        end

        def stub_attendees(attendees)
          return nil if attendees.nil?

          attendees.map do |att|
            att_obj = mock("attendee")
            att_obj.stubs(:email).returns(att[:email])
            att_obj.stubs(:response_status).returns(att[:response_status])
            att_obj.stubs(:self).returns(att[:self])
            att_obj.stubs(:resource).returns(att[:resource])
            att_obj
          end
        end

        def stub_single_event(
          id:,
          summary:,
          description: nil,
          location: nil,
          start: nil,
          end: nil,
          transparency: nil,
          recurrence: nil,
          recurring_event_id: nil,
          attendees: nil,
          color_id: nil
        )
          end_data = binding.local_variable_get(:end)

          item = mock("event_entry_#{id}")
          item.stubs(:id).returns(id)
          item.stubs(:summary).returns(summary)
          item.stubs(:description).returns(description)
          item.stubs(:location).returns(location)
          item.stubs(:transparency).returns(transparency)
          item.stubs(:recurrence).returns(recurrence)
          item.stubs(:recurring_event_id).returns(recurring_event_id)
          item.stubs(:color_id).returns(color_id)

          item.stubs(:start).returns(stub_event_time_obj("start_#{id}", start))

          default_end = start ? nil : {date_time: (Time.now + 3600).iso8601}
          item.stubs(:end).returns(stub_event_time_obj("end_#{id}", end_data || default_end))

          item.stubs(:attendees).returns(stub_attendees(attendees))

          item
        end

        def stub_events_response(events)
          items = events.map do |evt|
            item = mock("event_entry")
            item.stubs(:id).returns(evt[:id])
            item.stubs(:summary).returns(evt[:summary])
            item.stubs(:description).returns(evt[:description])
            item.stubs(:location).returns(evt[:location])
            item.stubs(:transparency).returns(evt[:transparency])
            item.stubs(:recurrence).returns(evt[:recurrence])
            item.stubs(:recurring_event_id).returns(evt[:recurring_event_id])
            item.stubs(:color_id).returns(evt[:color_id])

            item.stubs(:start).returns(stub_event_time_obj("start", evt[:start]))

            default_end = evt[:start] ? nil : {date_time: (Time.now + 3600).iso8601}
            item.stubs(:end).returns(stub_event_time_obj("end", evt[:end] || default_end))

            item.stubs(:attendees).returns(stub_attendees(evt[:attendees]))

            item
          end

          response = mock("events_list")
          response.stubs(:items).returns(items)
          response
        end
      end
    end
  end
end
