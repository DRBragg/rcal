require "test_helper"
require "rcal/commands/list"
require "rcal/models/calendar"
require "rcal/auth"
require "rcal/calendar_service"

module Rcal
  module Commands
    class ListTest < Minitest::Test
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

      def test_lists_calendars
        calendars = [
          build_calendar(name: "Personal", id: "personal@gmail.com"),
          build_calendar(name: "Work", id: "work@company.com")
        ]

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_calendars).returns(calendars)
        CalendarService.adapter = mock_adapter

        cmd = List.new
        cmd.call([], "list")

        assert_includes captured_output, "Personal"
        assert_includes captured_output, "Work"
      end

      def test_shows_calendar_ids
        calendars = [
          build_calendar(name: "My Calendar", id: "mycalendar@gmail.com")
        ]

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_calendars).returns(calendars)
        CalendarService.adapter = mock_adapter

        cmd = List.new
        cmd.call([], "list")

        assert_includes captured_output, "mycalendar@gmail.com"
      end

      def test_shows_primary_indicator
        calendars = [
          build_calendar(name: "Primary Cal", primary: true)
        ]

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_calendars).returns(calendars)
        CalendarService.adapter = mock_adapter

        cmd = List.new
        cmd.call([], "list")

        assert_match(/primary/i, captured_output)
      end

      def test_shows_message_when_no_calendars
        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:list_calendars).returns([])
        CalendarService.adapter = mock_adapter

        cmd = List.new
        cmd.call([], "list")

        assert_match(/no calendars/i, captured_output)
      end

      # Authentication tests

      def test_requires_authentication
        # Use a clean temp dir with no auth files
        clean_dir = Dir.mktmpdir
        Rcal::Configuration.stubs(:data_dir).returns(clean_dir)
        Auth.reset_adapter!

        cmd = List.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call([], "list")
        end

        assert_match(/not authenticated|run.*init/i, error.message)
      end

      # Help text test

      def test_has_help_text
        assert_match(/calendar/i, List.help.to_s)
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
