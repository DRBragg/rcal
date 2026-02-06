require "test_helper"
require "rcal/commands/add"
require "rcal/models/event"
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

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:create_event).with { |args|
          args[:calendar_id] == "primary" && args[:event].summary == "Team Meeting"
        }.returns(created_event)
        CalendarService.adapter = mock_adapter

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

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:create_event).returns(created_event)
        CalendarService.adapter = mock_adapter

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

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:create_event).with(
          calendar_id: "primary",
          event: anything
        ).returns(created_event)
        CalendarService.adapter = mock_adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow 3pm"
        ], "add")

        # Should use default 1 hour duration
      end

      def test_parses_duration_flag
        created_event = build_event(id: "new1", summary: "Quick Sync")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:create_event).returns(created_event)
        CalendarService.adapter = mock_adapter

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

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:create_event).with { |args|
          args[:event].location == "Conference Room A"
        }.returns(created_event)
        CalendarService.adapter = mock_adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow 3pm",
          "--location=Conference Room A"
        ], "add")
      end

      def test_accepts_description_flag
        created_event = build_event(id: "new1", summary: "Meeting")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:create_event).with { |args|
          args[:event].description == "Discuss Q1 goals"
        }.returns(created_event)
        CalendarService.adapter = mock_adapter

        cmd = Add.new
        cmd.call([
          "--title=Meeting",
          "--when=tomorrow 3pm",
          "--description=Discuss Q1 goals"
        ], "add")
      end

      def test_accepts_calendar_flag
        created_event = build_event(id: "new1", summary: "Work Meeting")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:create_event).with(
          calendar_id: "work@company.com",
          event: anything
        ).returns(created_event)
        CalendarService.adapter = mock_adapter

        cmd = Add.new
        cmd.call([
          "--title=Work Meeting",
          "--when=tomorrow 3pm",
          "--calendar=work@company.com"
        ], "add")
      end

      def test_creates_all_day_event
        created_event = build_event(id: "allday1", summary: "Vacation", all_day: true)

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:create_event).with { |args|
          args[:event].all_day? == true
        }.returns(created_event)
        CalendarService.adapter = mock_adapter

        cmd = Add.new
        cmd.call([
          "--title=Vacation",
          "--when=monday",
          "--all-day"
        ], "add")
      end

      # Output tests

      def test_displays_created_event
        created_event = build_event(
          id: "event123",
          summary: "Team Standup",
          start_time: Time.new(2024, 1, 15, 10, 0, 0)
        )

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:create_event).returns(created_event)
        CalendarService.adapter = mock_adapter

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
