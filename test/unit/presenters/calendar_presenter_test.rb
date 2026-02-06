require "test_helper"
require "rcal/models/calendar"
require "rcal/presenters/calendar_presenter"

module Rcal
  module Presenters
    class CalendarPresenterTest < Minitest::Test
      def test_includes_calendar_name
        calendar = build_calendar(name: "Work Calendar")
        presenter = CalendarPresenter.new(calendar)

        assert_includes presenter.to_s, "Work Calendar"
      end

      def test_includes_calendar_id
        calendar = build_calendar(id: "work@group.calendar.google.com")
        presenter = CalendarPresenter.new(calendar)

        assert_includes presenter.to_s, "work@group.calendar.google.com"
      end

      def test_shows_primary_indicator
        calendar = build_calendar(primary: true)
        presenter = CalendarPresenter.new(calendar)

        assert_match(/primary/i, presenter.to_s)
      end

      def test_shows_owner_indicator
        calendar = build_calendar(access_role: "owner")
        presenter = CalendarPresenter.new(calendar)

        assert_match(/owner/i, presenter.to_s)
      end

      def test_shows_read_only_for_reader_role
        calendar = build_calendar(access_role: "reader")
        presenter = CalendarPresenter.new(calendar)

        assert_match(/read.?only/i, presenter.to_s)
      end

      def test_does_not_show_read_only_for_writer
        calendar = build_calendar(access_role: "writer")
        presenter = CalendarPresenter.new(calendar)

        refute_match(/read.?only/i, presenter.to_s)
      end

      def test_compact_format_shows_name_only
        calendar = build_calendar(name: "My Calendar", id: "calendar123")
        presenter = CalendarPresenter.new(calendar)

        compact = presenter.to_s_compact

        assert_includes compact, "My Calendar"
        refute_includes compact, "calendar123"
      end

      def test_shows_color_indicator_when_present
        calendar = build_calendar(color: "#4285f4")
        presenter = CalendarPresenter.new(calendar)

        # Just verify it doesn't crash with color
        assert presenter.to_s
      end

      private

      def build_calendar(
        id: "test_calendar",
        name: "Test Calendar",
        color: nil,
        timezone: nil,
        description: nil,
        access_role: "owner",
        primary: false,
        selected: true
      )
        Rcal::Calendar.new(
          id: id,
          name: name,
          color: color,
          timezone: timezone,
          description: description,
          access_role: access_role,
          primary: primary,
          selected: selected
        )
      end
    end
  end
end
