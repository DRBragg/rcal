require "test_helper"
require "rcal/commands/agenda"
require "rcal/models/event"
require "rcal/auth"
require "rcal/calendar_service"

module Rcal
  module Commands
    class AgendaTest < Minitest::Test
      include AuthTestHelper

      def setup
        @temp_dir = Dir.mktmpdir
        @original_stdout = $stdout
        @output = StringIO.new
        $stdout = @output

        Rcal::Configuration.stubs(:data_dir).returns(@temp_dir)

        # Reset adapters to use fresh instances
        Auth.reset_adapter!
        CalendarService.reset_adapter!

        # Create token files so we appear authenticated
        write_auth_files(@temp_dir)

        @today = Date.today
      end

      def teardown
        $stdout = @original_stdout
        Auth.reset_adapter!
        CalendarService.reset_adapter!
        FileUtils.remove_entry(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
      end

      def captured_output
        @output.string
      end

      # Basic functionality tests

      def test_shows_todays_events_by_default
        events = [
          build_event(summary: "Morning Standup", start_time: today_at(9, 0)),
          build_event(summary: "Lunch Meeting", start_time: today_at(12, 0))
        ]

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_events).returns(events)
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.call([], "agenda")

        assert_includes captured_output, "Morning Standup"
        assert_includes captured_output, "Lunch Meeting"
      end

      def test_shows_no_events_message
        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_events).returns([])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.call([], "agenda")

        assert_match(/no events/i, captured_output)
      end

      # Date range parsing tests

      def test_parses_tomorrow
        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_events).returns([])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.call(["tomorrow"], "agenda")

        # If it didn't raise, tomorrow was parsed successfully
      end

      def test_parses_date_range
        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_events).returns([])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.stubs(:parse_date).with("monday").returns(Date.today)
        cmd.stubs(:parse_date).with("friday").returns(Date.today + 4)

        cmd.call(["monday", "friday"], "agenda")
      end

      # Predicate filtering tests

      def test_filters_with_must_be_flag
        accepted_event = build_event(summary: "Accepted", response_status: "accepted")
        declined_event = build_event(summary: "Declined", response_status: "declined")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_events).returns([accepted_event, declined_event])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.call(["--must-be=accepted"], "agenda")

        assert_includes captured_output, "Accepted"
        refute_includes captured_output, "Declined"
      end

      def test_filters_with_must_not_be_flag
        busy_event = build_event(summary: "Busy Meeting", transparency: "opaque")
        free_event = build_event(summary: "Free Block", transparency: "transparent")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_events).returns([busy_event, free_event])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.call(["--must-not-be=busy"], "agenda")

        assert_includes captured_output, "Free Block"
        refute_includes captured_output, "Busy Meeting"
      end

      def test_filters_with_multiple_predicates
        recurring_accepted = build_event(
          summary: "Recurring Accepted",
          response_status: "accepted",
          recurrence: ["RRULE:FREQ=WEEKLY"]
        )
        one_off_accepted = build_event(
          summary: "One-off Accepted",
          response_status: "accepted"
        )

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_events).returns([recurring_accepted, one_off_accepted])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.call(["--must-be=accepted,recurring"], "agenda")

        assert_includes captured_output, "Recurring Accepted"
        refute_includes captured_output, "One-off Accepted"
      end

      def test_rejects_invalid_predicate
        mock_adapter = mock("calendar_adapter")
        mock_adapter.stubs(:list_events).returns([])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call(["--must-be=invalid_predicate"], "agenda")
        end

        assert_match(/invalid.*predicate/i, error.message)
      end

      # Calendar filtering tests

      def test_filters_by_calendar
        mock_adapter = mock("calendar_adapter")

        # Should call list_events with the specific calendar
        mock_adapter.expects(:list_events).with(
          has_entry(calendar_id: "work@company.com")
        ).returns([])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.call(["--calendar=work@company.com"], "agenda")
      end

      def test_uses_primary_calendar_by_default
        mock_adapter = mock("calendar_adapter")

        mock_adapter.expects(:list_events).with(
          has_entry(calendar_id: "primary")
        ).returns([])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.call([], "agenda")
      end

      # Days flag tests

      def test_days_flag_passes_correct_date_range_to_adapter
        mock_adapter = mock("calendar_adapter")

        expected_time_min = @today.to_time
        expected_time_max = (@today + 7).to_time

        mock_adapter.expects(:list_events).with(
          has_entries(
            calendar_id: "primary",
            time_min: expected_time_min,
            time_max: expected_time_max
          )
        ).returns([])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.call(["--days=7"], "agenda")
      end

      def test_days_flag_with_start_date_passes_correct_range
        mock_adapter = mock("calendar_adapter")

        tomorrow = @today + 1
        expected_time_min = tomorrow.to_time
        expected_time_max = (tomorrow + 3).to_time

        mock_adapter.expects(:list_events).with(
          has_entries(
            time_min: expected_time_min,
            time_max: expected_time_max
          )
        ).returns([])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.stubs(:parse_date).with("tomorrow").returns(tomorrow)
        cmd.call(["tomorrow", "--days=3"], "agenda")
      end

      def test_days_flag_with_all_day_events
        all_day_event = build_event(
          summary: "Company Holiday",
          start_time: today_at(0, 0),
          all_day: true
        )
        timed_event = build_event(
          summary: "Standup",
          start_time: today_at(9, 0)
        )

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_events).returns([all_day_event, timed_event])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.call(["--days=7"], "agenda")

        assert_includes captured_output, "Company Holiday"
        assert_includes captured_output, "Standup"
      end

      def test_days_flag_shows_empty_days_in_range
        event = build_event(summary: "Monday Only", start_time: today_at(10, 0))

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_events).returns([event])
        CalendarService.adapter = mock_adapter

        cmd = Agenda.new
        cmd.call(["--days=3"], "agenda")

        # Should show "No events" for the days without events
        assert_match(/no events/i, captured_output)
      end

      # Authentication tests

      def test_requires_authentication
        # Remove auth files written by setup so we appear unauthenticated
        FileUtils.rm_f(File.join(@temp_dir, "google_tokens.yaml"))
        FileUtils.rm_f(File.join(@temp_dir, "client_credentials.json"))

        # Reset auth adapter to pick up the missing files
        Auth.reset_adapter!

        cmd = Agenda.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call([], "agenda")
        end

        assert_match(/not authenticated|run.*init/i, error.message)
      end

      # Help text test

      def test_has_help_text
        help = Agenda.help.to_s
        assert_match(/agenda|events/i, help)
        assert_match(/must-be|predicate/i, help)
      end

      private

      def today_at(hour, minute)
        Time.new(@today.year, @today.month, @today.day, hour, minute, 0)
      end

      def build_event(
        summary: "Test Event",
        start_time: nil,
        end_time: nil,
        all_day: false,
        response_status: nil,
        transparency: nil,
        recurrence: nil,
        attendees: nil
      )
        start_time ||= today_at(10, 0)
        end_time ||= start_time + 3600

        Rcal::Event.new(
          id: "event_#{rand(10000)}",
          summary: summary,
          start_time: start_time,
          end_time: end_time,
          all_day: all_day,
          response_status: response_status,
          transparency: transparency,
          recurrence: recurrence,
          attendees: attendees
        )
      end
    end
  end
end
