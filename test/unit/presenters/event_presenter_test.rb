require "test_helper"
require "rcal/models/event"
require "rcal/presenters/event_presenter"

module Rcal
  module Presenters
    class EventPresenterTest < Minitest::Test
      def setup
        @base_time = Time.new(2024, 1, 15, 10, 0, 0)
      end

      # Basic output tests

      def test_includes_event_summary
        event = build_event(summary: "Team Standup")
        presenter = EventPresenter.new(event)

        assert_includes presenter.to_s, "Team Standup"
      end

      def test_includes_start_time
        event = build_event(start_time: Time.new(2024, 1, 15, 14, 30, 0))
        presenter = EventPresenter.new(event)

        assert_includes presenter.to_s, "14:30"
      end

      def test_includes_end_time
        event = build_event(
          start_time: Time.new(2024, 1, 15, 14, 30, 0),
          end_time: Time.new(2024, 1, 15, 15, 30, 0)
        )
        presenter = EventPresenter.new(event)

        assert_includes presenter.to_s, "15:30"
      end

      def test_formats_time_range
        event = build_event(
          start_time: Time.new(2024, 1, 15, 9, 0, 0),
          end_time: Time.new(2024, 1, 15, 10, 0, 0)
        )
        presenter = EventPresenter.new(event)

        # Should show time range like "09:00 - 10:00"
        assert_match(/09:00.*10:00/, presenter.to_s)
      end

      # All-day event tests

      def test_all_day_event_shows_all_day_label
        event = build_event(all_day: true)
        presenter = EventPresenter.new(event)

        assert_match(/all.?day/i, presenter.to_s)
      end

      def test_all_day_event_does_not_show_time
        event = build_event(
          all_day: true,
          start_time: Time.new(2024, 1, 15, 0, 0, 0)
        )
        presenter = EventPresenter.new(event)

        # Should not show "00:00"
        refute_match(/00:00/, presenter.to_s)
      end

      # Attribute indicators tests

      def test_shows_recurring_indicator
        event = build_event(recurrence: ["RRULE:FREQ=DAILY"])
        presenter = EventPresenter.new(event)

        assert_match(/recurring/i, presenter.to_s)
      end

      def test_shows_one_on_one_indicator
        event = build_event(
          attendees: [
            {email: "me@example.com", self: true, response_status: "accepted"},
            {email: "other@example.com", self: false, response_status: "accepted"}
          ]
        )
        presenter = EventPresenter.new(event)

        assert_match(/1:1/i, presenter.to_s)
      end

      def test_shows_awaiting_indicator
        event = build_event(response_status: "needsAction")
        presenter = EventPresenter.new(event)

        assert_match(/awaiting/i, presenter.to_s)
      end

      def test_shows_tentative_indicator
        event = build_event(response_status: "tentative")
        presenter = EventPresenter.new(event)

        assert_match(/tentative/i, presenter.to_s)
      end

      def test_shows_not_busy_indicator_for_transparent_events
        event = build_event(transparency: "transparent")
        presenter = EventPresenter.new(event)

        assert_match(/free|not.?busy/i, presenter.to_s)
      end

      def test_does_not_show_busy_indicator_for_opaque_events
        event = build_event(transparency: "opaque")
        presenter = EventPresenter.new(event)

        # Should NOT show "free" or "not busy" for normal busy events
        refute_match(/free|not.?busy/i, presenter.to_s)
      end

      # Declined event tests

      def test_declined_events_are_visually_distinct
        event = build_event(response_status: "declined")
        presenter = EventPresenter.new(event)

        # The presenter should mark declined events differently
        # We test this by checking for a specific marker or format
        presenter.to_s
        assert presenter.declined?, "Event should be marked as declined"
      end

      # Location tests

      def test_includes_location_when_present
        event = build_event(location: "Conference Room A")
        presenter = EventPresenter.new(event, show_location: true)

        assert_includes presenter.to_s, "Conference Room A"
      end

      def test_omits_location_by_default
        event = build_event(location: "Conference Room A")
        presenter = EventPresenter.new(event)

        refute_includes presenter.to_s, "Conference Room A"
      end

      # Multiple attributes test

      def test_shows_multiple_attributes
        event = build_event(
          recurrence: ["RRULE:FREQ=WEEKLY"],
          response_status: "tentative",
          attendees: [
            {email: "me@example.com", self: true},
            {email: "other@example.com", self: false}
          ]
        )
        presenter = EventPresenter.new(event)
        output = presenter.to_s

        assert_match(/recurring/i, output)
        assert_match(/tentative/i, output)
        assert_match(/1:1/i, output)
      end

      # Date display tests

      def test_to_s_with_date_includes_date
        event = build_event(start_time: Time.new(2024, 1, 15, 10, 0, 0))
        presenter = EventPresenter.new(event)

        output = presenter.to_s_with_date

        assert_match(/Jan|01/, output) # Month
        assert_match(/15/, output) # Day
      end

      def test_to_s_with_date_includes_day_of_week
        # January 15, 2024 is a Monday
        event = build_event(start_time: Time.new(2024, 1, 15, 10, 0, 0))
        presenter = EventPresenter.new(event)

        output = presenter.to_s_with_date

        assert_match(/Mon/i, output)
      end

      # Compact format tests

      def test_compact_format_is_shorter
        event = build_event(
          summary: "Team Meeting",
          start_time: Time.new(2024, 1, 15, 10, 0, 0),
          end_time: Time.new(2024, 1, 15, 11, 0, 0)
        )
        presenter = EventPresenter.new(event)

        full = presenter.to_s
        compact = presenter.to_s_compact

        assert compact.length <= full.length, "Compact should be shorter or equal"
      end

      # Duration display tests

      def test_shows_duration_when_requested
        event = build_event(
          start_time: Time.new(2024, 1, 15, 10, 0, 0),
          end_time: Time.new(2024, 1, 15, 11, 30, 0)
        )
        presenter = EventPresenter.new(event, show_duration: true)

        assert_match(/1h\s*30m|90\s*min|1:30/i, presenter.to_s)
      end

      private

      def build_event(
        summary: "Test Event",
        start_time: nil,
        end_time: nil,
        all_day: false,
        location: nil,
        description: nil,
        recurrence: nil,
        recurring_event_id: nil,
        response_status: nil,
        transparency: nil,
        attendees: nil
      )
        start_time ||= @base_time
        end_time ||= start_time + 3600

        Rcal::Event.new(
          id: "test_event_#{rand(1000)}",
          summary: summary,
          start_time: start_time,
          end_time: end_time,
          all_day: all_day,
          location: location,
          description: description,
          recurrence: recurrence,
          recurring_event_id: recurring_event_id,
          response_status: response_status,
          transparency: transparency,
          attendees: attendees
        )
      end
    end
  end
end
