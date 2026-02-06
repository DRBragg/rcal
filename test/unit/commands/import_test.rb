require "test_helper"
require "rcal/commands/import"
require "rcal/ics_parser"
require "rcal/calendar_service"
require "rcal/auth"
require "rcal/models/event"

module Rcal
  module Commands
    class ImportTest < Minitest::Test
      def setup
        @temp_dir = Dir.mktmpdir
        Rcal::Configuration.stubs(:data_dir).returns(@temp_dir)

        Rcal::Auth.stubs(:authenticated?).returns(true)

        @created_events = []
        @mock_adapter = mock("calendar_adapter")
        Rcal::CalendarService.adapter = @mock_adapter
      end

      def teardown
        FileUtils.remove_entry(@temp_dir)
        Rcal::IcsParser.reset_adapter!
        Rcal::CalendarService.reset_adapter!
      end

      def stub_create_event
        @mock_adapter.stubs(:create_event).with { |kwargs|
          @created_events << kwargs
          true
        }.returns { |kwargs| kwargs[:event] }
      end

      def test_imports_single_event_from_file
        ics_file = create_ics_file(<<~ICS)
          BEGIN:VCALENDAR
          VERSION:2.0
          BEGIN:VEVENT
          DTSTART:20240115T140000Z
          DTEND:20240115T150000Z
          SUMMARY:Imported Meeting
          END:VEVENT
          END:VCALENDAR
        ICS

        @mock_adapter.expects(:create_event).with { |kwargs|
          @created_events << kwargs
          kwargs[:calendar_id] == "primary" && kwargs[:event].summary == "Imported Meeting"
        }.returns(nil)

        output = capture_output { Import.new.call([ics_file], "import") }

        assert_equal 1, @created_events.length
        assert_equal "Imported Meeting", @created_events.first[:event].summary
        assert_equal "primary", @created_events.first[:calendar_id]
        assert_includes output, "Imported 1 event"
      end

      def test_imports_multiple_events
        ics_file = create_ics_file(<<~ICS)
          BEGIN:VCALENDAR
          VERSION:2.0
          BEGIN:VEVENT
          DTSTART:20240115T090000Z
          DTEND:20240115T100000Z
          SUMMARY:Event One
          END:VEVENT
          BEGIN:VEVENT
          DTSTART:20240115T140000Z
          DTEND:20240115T150000Z
          SUMMARY:Event Two
          END:VEVENT
          END:VCALENDAR
        ICS

        @mock_adapter.expects(:create_event).twice.with { |kwargs|
          @created_events << kwargs
          true
        }.returns(nil)

        output = capture_output { Import.new.call([ics_file], "import") }

        assert_equal 2, @created_events.length
        assert_includes output, "Imported 2 events"
      end

      def test_imports_to_specified_calendar
        ics_file = create_ics_file(<<~ICS)
          BEGIN:VCALENDAR
          VERSION:2.0
          BEGIN:VEVENT
          DTSTART:20240115T140000Z
          DTEND:20240115T150000Z
          SUMMARY:Work Meeting
          END:VEVENT
          END:VCALENDAR
        ICS

        @mock_adapter.expects(:create_event).with { |kwargs|
          @created_events << kwargs
          kwargs[:calendar_id] == "work@company.com"
        }.returns(nil)

        capture_output { Import.new.call([ics_file, "--calendar=work@company.com"], "import") }

        assert_equal "work@company.com", @created_events.first[:calendar_id]
      end

      def test_shows_error_for_missing_file
        error = assert_raises(CLI::Kit::Abort) do
          Import.new.call(["/nonexistent/file.ics"], "import")
        end

        assert_includes error.message, "File not found"
      end

      def test_shows_error_when_no_file_provided
        error = assert_raises(CLI::Kit::Abort) do
          Import.new.call([], "import")
        end

        assert_includes error.message, "File path is required"
      end

      def test_shows_error_when_not_authenticated
        Rcal::Auth.stubs(:authenticated?).returns(false)

        error = assert_raises(CLI::Kit::Abort) do
          Import.new.call(["some_file.ics"], "import")
        end

        assert_includes error.message, "Not authenticated"
      end

      def test_shows_message_when_no_events_in_file
        ics_file = create_ics_file(<<~ICS)
          BEGIN:VCALENDAR
          VERSION:2.0
          PRODID:-//Test//Test//EN
          END:VCALENDAR
        ICS

        output = capture_output { Import.new.call([ics_file], "import") }

        assert_equal 0, @created_events.length
        assert_includes output, "No events found"
      end

      def test_displays_imported_event_summaries
        ics_file = create_ics_file(<<~ICS)
          BEGIN:VCALENDAR
          VERSION:2.0
          BEGIN:VEVENT
          DTSTART:20240115T140000Z
          DTEND:20240115T150000Z
          SUMMARY:Team Standup
          END:VEVENT
          END:VCALENDAR
        ICS

        @mock_adapter.expects(:create_event).returns(nil)

        output = capture_output { Import.new.call([ics_file], "import") }

        assert_includes output, "Team Standup"
      end

      private

      def create_ics_file(content)
        file_path = File.join(@temp_dir, "test_#{rand(10000)}.ics")
        File.write(file_path, content)
        file_path
      end

      def capture_output
        original_stdout = $stdout
        $stdout = StringIO.new
        yield
        $stdout.string
      ensure
        $stdout = original_stdout
      end
    end
  end
end
