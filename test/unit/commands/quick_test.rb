require "test_helper"
require "rcal/commands/quick"
require "rcal/models/event"
require "rcal/auth"
require "rcal/calendar_service"

module Rcal
  module Commands
    class QuickTest < Minitest::Test
      include AuthTestHelper

      def setup
        @temp_dir = Dir.mktmpdir
        @original_stdout = $stdout
        @output = StringIO.new
        $stdout = @output

        Rcal::Configuration.stubs(:data_dir).returns(@temp_dir)

        Auth.reset_adapter!
        CalendarService.reset_adapter!

        # Write auth files so we appear authenticated
        write_auth_files(@temp_dir)
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

      def test_creates_event_from_text
        created_event = build_event(
          id: "quick123",
          summary: "Lunch with Sarah tomorrow noon"
        )

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:quick_add).with(
          calendar_id: "primary",
          text: "Lunch with Sarah tomorrow noon"
        ).returns(created_event)
        CalendarService.adapter = mock_adapter

        cmd = Quick.new
        cmd.call(["Lunch with Sarah tomorrow noon"], "quick")

        assert_match(/created|added/i, captured_output)
        assert_includes captured_output, "Lunch with Sarah"
      end

      def test_requires_event_text
        cmd = Quick.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call([], "quick")
        end

        assert_match(/text|event.*required/i, error.message)
      end

      def test_joins_multiple_arguments_as_text
        created_event = build_event(
          id: "quick456",
          summary: "Team standup every weekday 10am"
        )

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:quick_add).with(
          calendar_id: "primary",
          text: "Team standup every weekday 10am"
        ).returns(created_event)
        CalendarService.adapter = mock_adapter

        cmd = Quick.new
        cmd.call(["Team", "standup", "every", "weekday", "10am"], "quick")
      end

      # Calendar selection tests

      def test_uses_primary_calendar_by_default
        created_event = build_event(id: "e1", summary: "Meeting")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:quick_add).with(
          has_entry(calendar_id: "primary")
        ).returns(created_event)
        CalendarService.adapter = mock_adapter

        cmd = Quick.new
        cmd.call(["Meeting tomorrow"], "quick")
      end

      def test_accepts_calendar_flag
        created_event = build_event(id: "e1", summary: "Work meeting")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:quick_add).with(
          has_entry(calendar_id: "work@company.com")
        ).returns(created_event)
        CalendarService.adapter = mock_adapter

        cmd = Quick.new
        cmd.call(["--calendar=work@company.com", "Work meeting tomorrow"], "quick")
      end

      def test_calendar_flag_at_end_of_args
        created_event = build_event(id: "e1", summary: "Work meeting")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:quick_add).with(
          calendar_id: "work@company.com",
          text: "Work meeting tomorrow"
        ).returns(created_event)
        CalendarService.adapter = mock_adapter

        cmd = Quick.new
        cmd.call(["Work meeting tomorrow", "--calendar=work@company.com"], "quick")
      end

      # Output tests

      def test_shows_created_event_details
        created_event = build_event(
          id: "event123",
          summary: "Dentist appointment",
          start_time: Time.new(2024, 1, 15, 14, 0, 0)
        )

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:quick_add).returns(created_event)
        CalendarService.adapter = mock_adapter

        cmd = Quick.new
        cmd.call(["Dentist appointment tomorrow 2pm"], "quick")

        assert_includes captured_output, "Dentist appointment"
      end

      # Authentication tests

      def test_requires_authentication
        # Use a clean temp dir with no auth files
        clean_dir = Dir.mktmpdir
        Rcal::Configuration.stubs(:data_dir).returns(clean_dir)
        Auth.reset_adapter!

        cmd = Quick.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call(["Meeting tomorrow"], "quick")
        end

        assert_match(/not authenticated|run.*init/i, error.message)
      end

      # Help text test

      def test_has_help_text
        help = Quick.help.to_s
        assert_match(/quick|natural.*language/i, help)
      end

      private

      def build_event(
        id:,
        summary:,
        start_time: nil,
        end_time: nil
      )
        start_time ||= Time.now + 3600
        end_time ||= start_time + 3600

        Rcal::Event.new(
          id: id,
          summary: summary,
          start_time: start_time,
          end_time: end_time
        )
      end
    end
  end
end
