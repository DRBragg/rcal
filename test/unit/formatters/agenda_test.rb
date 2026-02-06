require "test_helper"
require "rcal/models/event"
require "rcal/formatters/agenda"

module Rcal
  module Formatters
    class AgendaTest < Minitest::Test
      def setup
        @today = Date.new(2024, 1, 15) # Monday
      end

      # Basic formatting tests

      def test_formats_single_event
        events = [
          build_event(
            summary: "Team Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0)
          )
        ]

        formatter = Agenda.new(events)
        output = formatter.format

        assert_includes output, "Team Meeting"
        assert_includes output, "10:00"
      end

      def test_groups_events_by_day
        events = [
          build_event(summary: "Monday Event", start_time: Time.new(2024, 1, 15, 10, 0, 0)),
          build_event(summary: "Tuesday Event", start_time: Time.new(2024, 1, 16, 14, 0, 0))
        ]

        formatter = Agenda.new(events)
        output = formatter.format

        # Should have day headers
        assert_match(/Mon.*Jan.*15/i, output)
        assert_match(/Tue.*Jan.*16/i, output)

        # Events should appear under their days
        assert_includes output, "Monday Event"
        assert_includes output, "Tuesday Event"
      end

      def test_orders_events_by_time_within_day
        events = [
          build_event(summary: "Afternoon Meeting", start_time: Time.new(2024, 1, 15, 14, 0, 0)),
          build_event(summary: "Morning Standup", start_time: Time.new(2024, 1, 15, 9, 0, 0))
        ]

        formatter = Agenda.new(events)
        output = formatter.format

        morning_pos = output.index("Morning Standup")
        afternoon_pos = output.index("Afternoon Meeting")

        assert morning_pos < afternoon_pos, "Morning event should appear before afternoon event"
      end

      def test_handles_empty_events
        formatter = Agenda.new([])
        output = formatter.format

        assert_match(/no events/i, output)
      end

      # All-day events tests

      def test_all_day_events_appear_first
        events = [
          build_event(
            summary: "Timed Event",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            all_day: false
          ),
          build_event(
            summary: "Vacation",
            start_time: Time.new(2024, 1, 15, 0, 0, 0),
            all_day: true
          )
        ]

        formatter = Agenda.new(events)
        output = formatter.format

        vacation_pos = output.index("Vacation")
        timed_pos = output.index("Timed Event")

        assert vacation_pos < timed_pos, "All-day event should appear before timed events"
      end

      # Day header tests

      def test_shows_today_label_for_today
        today = Date.today
        events = [
          build_event(
            summary: "Today Event",
            start_time: Time.new(today.year, today.month, today.day, 10, 0, 0)
          )
        ]

        formatter = Agenda.new(events)
        output = formatter.format

        assert_match(/today/i, output)
      end

      def test_shows_tomorrow_label
        tomorrow = Date.today + 1
        events = [
          build_event(
            summary: "Tomorrow Event",
            start_time: Time.new(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0, 0)
          )
        ]

        formatter = Agenda.new(events)
        output = formatter.format

        assert_match(/tomorrow/i, output)
      end

      # Declined events tests

      def test_shows_declined_events_differently
        events = [
          build_event(summary: "Declined Meeting", response_status: "declined")
        ]

        formatter = Agenda.new(events)
        output = formatter.format

        # Should still show the event but marked as declined
        assert_includes output, "Declined Meeting"
        assert_match(/declined/i, output)
      end

      def test_can_hide_declined_events
        events = [
          build_event(summary: "Accepted Meeting", response_status: "accepted"),
          build_event(summary: "Declined Meeting", response_status: "declined")
        ]

        formatter = Agenda.new(events, hide_declined: true)
        output = formatter.format

        assert_includes output, "Accepted Meeting"
        refute_includes output, "Declined Meeting"
      end

      # Multi-day range tests

      def test_shows_days_without_events_in_range
        # Events on Monday and Wednesday, but not Tuesday
        events = [
          build_event(summary: "Monday Event", start_time: Time.new(2024, 1, 15, 10, 0, 0)),
          build_event(summary: "Wednesday Event", start_time: Time.new(2024, 1, 17, 10, 0, 0))
        ]

        date_range = Date.new(2024, 1, 15)..Date.new(2024, 1, 17)
        formatter = Agenda.new(events, date_range: date_range)
        output = formatter.format

        # Tuesday should appear with "no events" indication
        assert_match(/Tue.*Jan.*16/i, output)
      end

      def test_can_skip_empty_days
        events = [
          build_event(summary: "Monday Event", start_time: Time.new(2024, 1, 15, 10, 0, 0)),
          build_event(summary: "Wednesday Event", start_time: Time.new(2024, 1, 17, 10, 0, 0))
        ]

        date_range = Date.new(2024, 1, 15)..Date.new(2024, 1, 17)
        formatter = Agenda.new(events, date_range: date_range, show_empty_days: false)
        output = formatter.format

        # Should not show Tuesday header when skipping empty days
        refute_match(/Tue.*Jan.*16.*\n.*no events/i, output)
      end

      # Formatting options tests

      def test_compact_format
        events = [
          build_event(
            summary: "Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0)
          )
        ]

        formatter = Agenda.new(events, compact: true)
        output = formatter.format

        # Compact format should be more condensed
        assert_includes output, "Meeting"
      end

      def test_show_ids_includes_event_id
        events = [
          Rcal::Event.new(
            id: "abc123xyz",
            summary: "Team Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0)
          )
        ]

        formatter = Agenda.new(events, show_ids: true)
        output = formatter.format

        assert_includes output, "Team Meeting"
        assert_includes output, "ID: abc123xyz"
      end

      def test_show_ids_false_by_default
        events = [
          Rcal::Event.new(
            id: "abc123xyz",
            summary: "Team Meeting",
            start_time: Time.new(2024, 1, 15, 10, 0, 0),
            end_time: Time.new(2024, 1, 15, 11, 0, 0)
          )
        ]

        formatter = Agenda.new(events)
        output = formatter.format

        assert_includes output, "Team Meeting"
        refute_includes output, "ID: abc123xyz"
      end

      private

      def build_event(
        summary: "Test Event",
        start_time: nil,
        end_time: nil,
        all_day: false,
        response_status: nil,
        recurrence: nil,
        attendees: nil
      )
        start_time ||= Time.new(2024, 1, 15, 10, 0, 0)
        end_time ||= start_time + 3600

        Rcal::Event.new(
          id: "event_#{rand(10000)}",
          summary: summary,
          start_time: start_time,
          end_time: end_time,
          all_day: all_day,
          response_status: response_status,
          recurrence: recurrence,
          attendees: attendees
        )
      end
    end
  end
end
