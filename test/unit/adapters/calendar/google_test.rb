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
          attendees: nil
        )
          item = mock("event_entry_#{id}")
          item.stubs(:id).returns(id)
          item.stubs(:summary).returns(summary)
          item.stubs(:description).returns(description)
          item.stubs(:location).returns(location)
          item.stubs(:transparency).returns(transparency)
          item.stubs(:recurrence).returns(recurrence)
          item.stubs(:recurring_event_id).returns(recurring_event_id)

          # Start time
          start_obj = mock("start_#{id}")
          if start
            start_obj.stubs(:date_time).returns(start[:date_time] ? Time.parse(start[:date_time]) : nil)
            start_obj.stubs(:date).returns(start[:date])
            start_obj.stubs(:time_zone).returns(start[:time_zone])
          else
            start_obj.stubs(:date_time).returns(Time.now)
            start_obj.stubs(:date).returns(nil)
            start_obj.stubs(:time_zone).returns(nil)
          end
          item.stubs(:start).returns(start_obj)

          # End time
          end_obj = mock("end_#{id}")
          if binding.local_variable_get(:end)
            end_data = binding.local_variable_get(:end)
            end_obj.stubs(:date_time).returns(end_data[:date_time] ? Time.parse(end_data[:date_time]) : nil)
            end_obj.stubs(:date).returns(end_data[:date])
            end_obj.stubs(:time_zone).returns(end_data[:time_zone])
          else
            end_obj.stubs(:date_time).returns(Time.now + 3600)
            end_obj.stubs(:date).returns(nil)
            end_obj.stubs(:time_zone).returns(nil)
          end
          item.stubs(:end).returns(end_obj)

          # Attendees
          if attendees
            attendee_objs = attendees.map do |att|
              att_obj = mock("attendee")
              att_obj.stubs(:email).returns(att[:email])
              att_obj.stubs(:response_status).returns(att[:response_status])
              att_obj.stubs(:self).returns(att[:self])
              att_obj.stubs(:resource).returns(att[:resource])
              att_obj
            end
            item.stubs(:attendees).returns(attendee_objs)
          else
            item.stubs(:attendees).returns(nil)
          end

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

            # Start time
            start_obj = mock("start")
            if evt[:start]
              start_obj.stubs(:date_time).returns(evt[:start][:date_time] ? Time.parse(evt[:start][:date_time]) : nil)
              start_obj.stubs(:date).returns(evt[:start][:date])
              start_obj.stubs(:time_zone).returns(evt[:start][:time_zone])
            else
              start_obj.stubs(:date_time).returns(Time.now)
              start_obj.stubs(:date).returns(nil)
              start_obj.stubs(:time_zone).returns(nil)
            end
            item.stubs(:start).returns(start_obj)

            # End time
            end_obj = mock("end")
            if evt[:end]
              end_obj.stubs(:date_time).returns(evt[:end][:date_time] ? Time.parse(evt[:end][:date_time]) : nil)
              end_obj.stubs(:date).returns(evt[:end][:date])
              end_obj.stubs(:time_zone).returns(evt[:end][:time_zone])
            else
              end_obj.stubs(:date_time).returns(Time.now + 3600)
              end_obj.stubs(:date).returns(nil)
              end_obj.stubs(:time_zone).returns(nil)
            end
            item.stubs(:end).returns(end_obj)

            # Attendees
            if evt[:attendees]
              attendee_objs = evt[:attendees].map do |att|
                att_obj = mock("attendee")
                att_obj.stubs(:email).returns(att[:email])
                att_obj.stubs(:response_status).returns(att[:response_status])
                att_obj.stubs(:self).returns(att[:self])
                att_obj.stubs(:resource).returns(att[:resource])
                att_obj
              end
              item.stubs(:attendees).returns(attendee_objs)
            else
              item.stubs(:attendees).returns(nil)
            end

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
