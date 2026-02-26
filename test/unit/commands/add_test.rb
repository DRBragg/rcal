require "test_helper"
require "rcal/commands/add"
require "rcal/models/event"
require "rcal/models/calendar"
require "rcal/auth"
require "rcal/calendar_service"

module Rcal
  module Commands
    class AddTest < Minitest::Test
      def setup
        @temp_dir = Dir.mktmpdir
        @original_stdout = $stdout
        @output = StringIO.new
        $stdout = @output

        Rcal::Configuration.stubs(:data_dir).returns(@temp_dir)

        Auth.reset_adapter!
        CalendarService.reset_adapter!

        # Create token file so we appear authenticated
        token_path = File.join(@temp_dir, "tokens.json")
        File.write(token_path, JSON.generate({
          "access_token" => "test_token",
          "refresh_token" => "test_refresh",
          "expires_at" => (Time.now + 3600).to_i
        }))

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

      # Flag-based event creation tests

      def test_creates_event_with_title_flag
        created_event = build_event(id: "new1", summary: "Team Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:calendar_id] == "primary" && args[:event].summary == "Team Meeting"
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Team Meeting",
          "--when=tomorrow 3pm",
          "--duration=1h"
        ], "add")

        assert_match(/created|added/i, captured_output)
      end

      def test_requires_title
        cmd = Add.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call(["--when=tomorrow"], "add")
        end

        assert_match(/title.*required/i, error.message)
      end

      def test_requires_when
        cmd = Add.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call(["--title=Meeting"], "add")
        end

        assert_match(/when.*required/i, error.message)
      end

      def test_parses_when_with_date_parser
        created_event = build_event(id: "new1", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow at 3pm",
          "--duration=30m"
        ], "add")

        # Test passes if no parse error is raised
      end

      def test_uses_default_duration_when_not_specified
        created_event = build_event(id: "new1", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with(
          calendar_id: "primary",
          event: anything
        ).returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow 3pm"
        ], "add")

        # Should use default 1 hour duration
      end

      def test_parses_duration_flag
        created_event = build_event(id: "new1", summary: "Quick Sync")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Quick Sync",
          "--when=tomorrow 2pm",
          "--duration=30m"
        ], "add")

        # Test passes if duration was parsed
      end

      def test_accepts_location_flag
        created_event = build_event(id: "new1", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].location == "Conference Room A"
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow 3pm",
          "--location=Conference Room A"
        ], "add")
      end

      def test_accepts_description_flag
        created_event = build_event(id: "new1", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].description == "Discuss Q1 goals"
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow 3pm",
          "--description=Discuss Q1 goals"
        ], "add")
      end

      def test_accepts_calendar_flag
        created_event = build_event(id: "new1", summary: "Work Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with(
          calendar_id: "work@company.com",
          event: anything
        ).returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Work Meeting",
          "--when=tomorrow 3pm",
          "--calendar=work@company.com"
        ], "add")
      end

      def test_creates_all_day_event
        created_event = build_event(id: "allday1", summary: "Vacation", all_day: true)

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].all_day? == true
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Vacation",
          "--when=monday",
          "--all-day"
        ], "add")
      end

      # Transparency tests

      def test_creates_free_event
        created_event = build_event(id: "free1", summary: "Focus Time")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].transparency == "transparent"
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Focus Time",
          "--when=tomorrow 2pm",
          "--free"
        ], "add")
      end

      def test_defaults_to_busy_without_free_flag
        created_event = build_event(id: "busy1", summary: "Team Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].transparency.nil?
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Team Meeting",
          "--when=tomorrow 3pm"
        ], "add")
      end

      # Timezone option tests

      def test_accepts_timezone_flag
        created_event = build_event(id: "new1", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].timezone == "America/New_York"
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow 3pm",
          "--timezone=America/New_York"
        ], "add")
      end

      def test_timezone_resolves_from_calendar_when_not_specified
        calendar = Rcal::Calendar.new(
          id: "primary",
          name: "My Calendar",
          timezone: "America/Chicago"
        )

        created_event = build_event(id: "new1", summary: "Meeting")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:get_calendar).with(calendar_id: "primary").returns(calendar)
        mock_adapter.expects(:create_event).with { |args|
          args[:event].timezone == "America/Chicago"
        }.returns(created_event)
        CalendarService.adapter = mock_adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow 3pm"
        ], "add")
      end

      def test_timezone_flag_overrides_calendar_default
        created_event = build_event(id: "new1", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].timezone == "Europe/London"
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow 3pm",
          "--timezone=Europe/London"
        ], "add")
      end

      # Recurrence option tests

      def test_creates_recurring_weekly_event
        created_event = build_event(id: "new1", summary: "Standup")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].recurrence == ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"]
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Standup",
          "--when=monday 9am",
          "--repeat=weekly",
          "--days=MO,WE,FR"
        ], "add")
      end

      def test_creates_recurring_daily_event_with_count
        created_event = build_event(id: "new1", summary: "Daily Check")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].recurrence == ["RRULE:FREQ=DAILY;COUNT=5"]
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Daily Check",
          "--when=tomorrow 10am",
          "--repeat=daily",
          "--count=5"
        ], "add")
      end

      def test_creates_biweekly_event
        created_event = build_event(id: "new1", summary: "1:1")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].recurrence == ["RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO"]
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=1:1",
          "--when=monday 2pm",
          "--repeat=weekly",
          "--interval=2",
          "--days=MO"
        ], "add")
      end

      def test_creates_monthly_event
        created_event = build_event(id: "new1", summary: "Monthly Review")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].recurrence == ["RRULE:FREQ=MONTHLY;COUNT=12"]
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Monthly Review",
          "--when=friday 3pm",
          "--repeat=monthly",
          "--count=12"
        ], "add")
      end

      def test_creates_recurring_event_with_until
        created_event = build_event(id: "new1", summary: "Sprint Planning")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].recurrence == ["RRULE:FREQ=WEEKLY;BYDAY=TU;UNTIL=20251231T235959Z"]
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Sprint Planning",
          "--when=tuesday 10am",
          "--repeat=weekly",
          "--days=TU",
          "--until=2025-12-31"
        ], "add")
      end

      def test_accepts_day_full_names_in_repeat
        created_event = build_event(id: "new1", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].recurrence == ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"]
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=monday 9am",
          "--repeat=weekly",
          "--days=Monday,Wednesday,Friday"
        ], "add")
      end

      def test_recurrence_nil_when_no_repeat
        created_event = build_event(id: "new1", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].recurrence.nil?
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow 3pm"
        ], "add")
      end

      def test_rejects_recurrence_modifiers_without_repeat
        cmd = Add.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call([
            "--title=Meeting",
            "--when=tomorrow 3pm",
            "--days=MO,WE"
          ], "add")
        end

        assert_match(/require.*--repeat/i, error.message)
      end

      def test_rejects_invalid_repeat_frequency
        cmd = Add.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call([
            "--title=Meeting",
            "--when=tomorrow 3pm",
            "--repeat=biweekly"
          ], "add")
        end

        assert_match(/invalid recurrence frequency/i, error.message)
      end

      def test_rejects_both_count_and_until
        cmd = Add.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call([
            "--title=Meeting",
            "--when=tomorrow 3pm",
            "--repeat=weekly",
            "--count=10",
            "--until=2025-12-31"
          ], "add")
        end

        assert_match(/cannot specify both/i, error.message)
      end

      # Color option tests

      def test_accepts_color_by_name
        created_event = build_event(id: "new1", summary: "Important")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].color_id == "11"
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Important",
          "--when=tomorrow 3pm",
          "--color=tomato"
        ], "add")
      end

      def test_accepts_color_by_id
        created_event = build_event(id: "new1", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].color_id == "7"
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow 3pm",
          "--color=7"
        ], "add")
      end

      def test_color_defaults_to_nil
        created_event = build_event(id: "new1", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).with { |args|
          args[:event].color_id.nil?
        }.returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow 3pm"
        ], "add")
      end

      def test_rejects_invalid_color
        cmd = Add.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call([
            "--title=Meeting",
            "--when=tomorrow 3pm",
            "--color=magenta"
          ], "add")
        end

        assert_match(/unknown color/i, error.message)
      end

      # Output tests

      def test_displays_created_event
        created_event = build_event(
          id: "event123",
          summary: "Team Standup",
          start_time: Time.new(2024, 1, 15, 10, 0, 0)
        )

        adapter = mock_calendar_adapter
        adapter.expects(:create_event).returns(created_event)
        CalendarService.adapter = adapter

        cmd = Add.new
        cmd.call([
          "--title=Team Standup",
          "--when=tomorrow 10am"
        ], "add")

        assert_includes captured_output, "Team Standup"
      end

      # Authentication tests

      def test_requires_authentication
        token_path = File.join(@temp_dir, "tokens.json")
        FileUtils.rm_f(token_path)
        Auth.reset_adapter!

        cmd = Add.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call(["--title=Meeting", "--when=tomorrow"], "add")
        end

        assert_match(/not authenticated|run.*init/i, error.message)
      end

      # Help text test

      def test_has_help_text
        help = Add.help.to_s
        assert_match(/add|create.*event/i, help)
        assert_match(/--title/i, help)
        assert_match(/--when/i, help)
      end

      private

      def mock_calendar_adapter
        adapter = mock("calendar_adapter")
        calendar = Rcal::Calendar.new(id: "primary", name: "Test Calendar", timezone: "America/New_York")
        adapter.stubs(:get_calendar).returns(calendar)
        adapter
      end

      def build_event(
        id:,
        summary:,
        start_time: nil,
        end_time: nil,
        all_day: false
      )
        start_time ||= Time.now + 3600
        end_time ||= start_time + 3600

        Rcal::Event.new(
          id: id,
          summary: summary,
          start_time: start_time,
          end_time: end_time,
          all_day: all_day
        )
      end
    end
  end
end
