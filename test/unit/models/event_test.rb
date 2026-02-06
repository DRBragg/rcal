require "test_helper"
require "timecop"
require "rcal/models/event"

module Rcal
  class EventTest < Minitest::Test
    def setup
      @frozen_time = Time.local(2026, 1, 30, 10, 0, 0)
      Timecop.freeze(@frozen_time)
    end

    def teardown
      Timecop.return
    end

    # Basic attributes

    def test_has_id
      event = Event.new(id: "abc123", summary: "Meeting", start_time: Time.now)

      assert_equal "abc123", event.id
    end

    def test_has_summary
      event = Event.new(summary: "Team Standup", start_time: Time.now)

      assert_equal "Team Standup", event.summary
    end

    def test_has_start_time
      start = Time.local(2026, 1, 30, 14, 0, 0)
      event = Event.new(summary: "Meeting", start_time: start)

      assert_equal start, event.start_time
    end

    def test_has_end_time
      start_time = Time.local(2026, 1, 30, 14, 0, 0)
      end_time = Time.local(2026, 1, 30, 15, 0, 0)
      event = Event.new(summary: "Meeting", start_time: start_time, end_time: end_time)

      assert_equal end_time, event.end_time
    end

    def test_end_time_defaults_to_start_time
      start = Time.local(2026, 1, 30, 14, 0, 0)
      event = Event.new(summary: "Meeting", start_time: start)

      assert_equal start, event.end_time
    end

    def test_has_description
      event = Event.new(summary: "Meeting", start_time: Time.now, description: "Discuss Q1 goals")

      assert_equal "Discuss Q1 goals", event.description
    end

    def test_has_location
      event = Event.new(summary: "Meeting", start_time: Time.now, location: "Conference Room A")

      assert_equal "Conference Room A", event.location
    end

    def test_has_calendar_id
      event = Event.new(summary: "Meeting", start_time: Time.now, calendar_id: "work@example.com")

      assert_equal "work@example.com", event.calendar_id
    end

    # All-day events

    def test_all_day_defaults_to_false
      event = Event.new(summary: "Meeting", start_time: Time.now)

      refute event.all_day?
    end

    def test_all_day_can_be_set
      event = Event.new(summary: "Vacation", start_time: Date.today, all_day: true)

      assert event.all_day?
    end

    # Duration

    def test_duration_returns_difference_in_seconds
      start_time = Time.local(2026, 1, 30, 14, 0, 0)
      end_time = Time.local(2026, 1, 30, 15, 30, 0)
      event = Event.new(summary: "Meeting", start_time: start_time, end_time: end_time)

      assert_equal 5400, event.duration # 1.5 hours in seconds
    end

    def test_duration_returns_zero_when_no_end_time
      start = Time.local(2026, 1, 30, 14, 0, 0)
      event = Event.new(summary: "Meeting", start_time: start)

      assert_equal 0, event.duration
    end

    # Response status predicates

    def test_accepted_when_response_status_is_accepted
      event = Event.new(summary: "Meeting", start_time: Time.now, response_status: "accepted")

      assert event.accepted?
    end

    def test_not_accepted_when_response_status_is_other
      event = Event.new(summary: "Meeting", start_time: Time.now, response_status: "declined")

      refute event.accepted?
    end

    def test_declined_when_response_status_is_declined
      event = Event.new(summary: "Meeting", start_time: Time.now, response_status: "declined")

      assert event.declined?
    end

    def test_awaiting_when_response_status_is_needs_action
      event = Event.new(summary: "Meeting", start_time: Time.now, response_status: "needsAction")

      assert event.awaiting?
    end

    def test_tentative_when_response_status_is_tentative
      event = Event.new(summary: "Meeting", start_time: Time.now, response_status: "tentative")

      assert event.tentative?
    end

    # Temporal predicates

    def test_past_when_end_time_is_before_now
      start_time = Time.local(2026, 1, 30, 8, 0, 0)
      end_time = Time.local(2026, 1, 30, 9, 0, 0)
      event = Event.new(summary: "Meeting", start_time: start_time, end_time: end_time)

      assert event.past?
    end

    def test_not_past_when_end_time_is_after_now
      start_time = Time.local(2026, 1, 30, 11, 0, 0)
      end_time = Time.local(2026, 1, 30, 12, 0, 0)
      event = Event.new(summary: "Meeting", start_time: start_time, end_time: end_time)

      refute event.past?
    end

    def test_future_when_start_time_is_after_now
      start_time = Time.local(2026, 1, 30, 11, 0, 0)
      event = Event.new(summary: "Meeting", start_time: start_time)

      assert event.future?
    end

    def test_not_future_when_start_time_is_before_now
      start_time = Time.local(2026, 1, 30, 9, 0, 0)
      event = Event.new(summary: "Meeting", start_time: start_time)

      refute event.future?
    end

    def test_current_when_now_is_between_start_and_end
      start_time = Time.local(2026, 1, 30, 9, 0, 0)
      end_time = Time.local(2026, 1, 30, 11, 0, 0)
      event = Event.new(summary: "Meeting", start_time: start_time, end_time: end_time)

      assert event.current?
    end

    def test_not_current_when_now_is_outside_start_and_end
      start_time = Time.local(2026, 1, 30, 11, 0, 0)
      end_time = Time.local(2026, 1, 30, 12, 0, 0)
      event = Event.new(summary: "Meeting", start_time: start_time, end_time: end_time)

      refute event.current?
    end

    # Busy predicate

    def test_busy_when_transparency_is_opaque
      event = Event.new(summary: "Meeting", start_time: Time.now, transparency: "opaque")

      assert event.busy?
    end

    def test_busy_when_transparency_is_nil
      event = Event.new(summary: "Meeting", start_time: Time.now)

      assert event.busy?
    end

    def test_not_busy_when_transparency_is_transparent
      event = Event.new(summary: "OOO", start_time: Time.now, transparency: "transparent")

      refute event.busy?
    end

    # Recurring predicate

    def test_recurring_when_recurrence_is_present
      event = Event.new(summary: "Standup", start_time: Time.now, recurrence: ["RRULE:FREQ=DAILY"])

      assert event.recurring?
    end

    def test_recurring_when_recurring_event_id_is_present
      event = Event.new(summary: "Standup", start_time: Time.now, recurring_event_id: "abc123")

      assert event.recurring?
    end

    def test_not_recurring_when_neither_present
      event = Event.new(summary: "Meeting", start_time: Time.now)

      refute event.recurring?
    end

    # One-on-one predicate

    def test_one_on_one_with_exactly_two_attendees_including_self
      event = Event.new(
        summary: "1:1",
        start_time: Time.now,
        attendees: [
          {email: "me@example.com", self: true, response_status: "accepted"},
          {email: "other@example.com", self: false, response_status: "accepted"}
        ]
      )

      assert event.one_on_one?
    end

    def test_not_one_on_one_with_three_attendees
      event = Event.new(
        summary: "Team Meeting",
        start_time: Time.now,
        attendees: [
          {email: "me@example.com", self: true, response_status: "accepted"},
          {email: "a@example.com", self: false, response_status: "accepted"},
          {email: "b@example.com", self: false, response_status: "accepted"}
        ]
      )

      refute event.one_on_one?
    end

    def test_not_one_on_one_with_no_attendees
      event = Event.new(summary: "Solo work", start_time: Time.now)

      refute event.one_on_one?
    end

    def test_not_one_on_one_without_self_attending
      event = Event.new(
        summary: "1:1",
        start_time: Time.now,
        attendees: [
          {email: "a@example.com", self: false, response_status: "accepted"},
          {email: "b@example.com", self: false, response_status: "accepted"}
        ]
      )

      refute event.one_on_one?
    end

    # Commitment predicate

    def test_commitment_with_multiple_attendees_and_not_declined
      event = Event.new(
        summary: "Meeting",
        start_time: Time.now,
        response_status: "accepted",
        attendees: [
          {email: "me@example.com", self: true, response_status: "accepted"},
          {email: "other@example.com", self: false, response_status: "accepted"}
        ]
      )

      assert event.commitment?
    end

    def test_not_commitment_when_declined
      event = Event.new(
        summary: "Meeting",
        start_time: Time.now,
        response_status: "declined",
        attendees: [
          {email: "me@example.com", self: true, response_status: "declined"},
          {email: "other@example.com", self: false, response_status: "accepted"}
        ]
      )

      refute event.commitment?
    end

    def test_not_commitment_with_single_attendee
      event = Event.new(
        summary: "Meeting",
        start_time: Time.now,
        attendees: [
          {email: "me@example.com", self: true, response_status: "accepted"}
        ]
      )

      refute event.commitment?
    end

    def test_not_commitment_with_no_attendees
      event = Event.new(summary: "Solo", start_time: Time.now)

      refute event.commitment?
    end

    # Timezone support

    def test_has_timezone
      event = Event.new(summary: "Meeting", start_time: Time.now, timezone: "America/New_York")

      assert_equal "America/New_York", event.timezone
    end

    def test_timezone_defaults_to_nil
      event = Event.new(summary: "Meeting", start_time: Time.now)

      assert_nil event.timezone
    end

    def test_past_uses_event_timezone_when_set
      # Freeze time to 10:00 AM UTC (5:00 AM Eastern)
      Timecop.freeze(Time.utc(2026, 1, 30, 10, 0, 0)) do
        # Event ended at 6:00 AM Eastern (11:00 AM UTC)
        # So at 10:00 AM UTC, this event is NOT past yet
        start_time = Time.utc(2026, 1, 30, 9, 0, 0)  # 4:00 AM Eastern
        end_time = Time.utc(2026, 1, 30, 11, 0, 0)   # 6:00 AM Eastern

        event = Event.new(
          summary: "Meeting",
          start_time: start_time,
          end_time: end_time,
          timezone: "America/New_York"
        )

        refute event.past?
      end
    end

    def test_current_compares_times_correctly_across_timezones
      # Freeze time to 10:00 AM UTC
      Timecop.freeze(Time.utc(2026, 1, 30, 10, 0, 0)) do
        # Event from 9:00 AM to 11:00 AM UTC - we're in the middle
        start_time = Time.utc(2026, 1, 30, 9, 0, 0)
        end_time = Time.utc(2026, 1, 30, 11, 0, 0)

        event = Event.new(
          summary: "Meeting",
          start_time: start_time,
          end_time: end_time,
          timezone: "America/New_York"
        )

        assert event.current?
      end
    end

    def test_start_time_in_timezone_returns_time_in_event_timezone
      # Create event with UTC time but America/New_York timezone
      utc_time = Time.utc(2026, 1, 30, 15, 0, 0) # 3:00 PM UTC = 10:00 AM Eastern
      event = Event.new(
        summary: "Meeting",
        start_time: utc_time,
        timezone: "America/New_York"
      )

      local_time = event.start_time_in_timezone

      assert_equal 10, local_time.hour # 10:00 AM Eastern
      # Zone abbreviation varies by system (EST, America/New_York, etc.)
      assert_includes ["EST", "EDT", "America/New_York"], local_time.zone
    end

    def test_end_time_in_timezone_returns_time_in_event_timezone
      utc_start = Time.utc(2026, 1, 30, 15, 0, 0)
      utc_end = Time.utc(2026, 1, 30, 16, 0, 0) # 4:00 PM UTC = 11:00 AM Eastern
      event = Event.new(
        summary: "Meeting",
        start_time: utc_start,
        end_time: utc_end,
        timezone: "America/New_York"
      )

      local_time = event.end_time_in_timezone

      assert_equal 11, local_time.hour # 11:00 AM Eastern
    end

    def test_start_time_in_timezone_returns_start_time_when_no_timezone
      time = Time.local(2026, 1, 30, 10, 0, 0)
      event = Event.new(summary: "Meeting", start_time: time)

      assert_equal time, event.start_time_in_timezone
    end
  end
end
