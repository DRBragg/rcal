require "test_helper"
require "rcal/commands/edit"
require "rcal/models/event"
require "rcal/models/calendar"
require "rcal/auth"
require "rcal/calendar_service"

module Rcal
  module Commands
    class EditTest < Minitest::Test
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

      def test_requires_event_id
        cmd = Edit.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call([], "edit")
        end

        assert_match(/event.*id.*required/i, error.message)
      end

      def test_fetches_event_before_editing
        existing_event = build_event(id: "event123", summary: "Original Meeting")
        updated_event = build_event(id: "event123", summary: "Updated Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).with(
          calendar_id: "primary",
          event_id: "event123"
        ).returns(existing_event)
        adapter.expects(:update_event).returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--title=Updated Meeting"], "edit")
      end

      def test_updates_event_title
        existing_event = build_event(id: "event123", summary: "Original")
        updated_event = build_event(id: "event123", summary: "New Title")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].summary == "New Title"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--title=New Title"], "edit")

        assert_match(/updated/i, captured_output)
      end

      def test_updates_event_location
        existing_event = build_event(id: "event123", summary: "Meeting")
        updated_event = build_event(id: "event123", summary: "Meeting", location: "Room 101")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].location == "Room 101"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--location=Room 101"], "edit")
      end

      def test_updates_event_description
        existing_event = build_event(id: "event123", summary: "Meeting")
        updated_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].description == "New description"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--description=New description"], "edit")
      end

      def test_updates_event_time
        existing_event = build_event(
          id: "event123",
          summary: "Meeting",
          start_time: Time.new(2024, 1, 15, 10, 0, 0)
        )
        updated_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--when=tomorrow 3pm"], "edit")
      end

      def test_preserves_unchanged_fields
        existing_event = build_event(
          id: "event123",
          summary: "Original Title",
          location: "Original Location",
          description: "Original Description"
        )
        updated_event = build_event(id: "event123", summary: "New Title")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          # Title changes, but location and description should be preserved
          args[:event].summary == "New Title" &&
            args[:event].location == "Original Location" &&
            args[:event].description == "Original Description"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--title=New Title"], "edit")
      end

      def test_accepts_calendar_flag
        existing_event = build_event(id: "event123", summary: "Meeting")
        updated_event = build_event(id: "event123", summary: "Updated")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).with(
          calendar_id: "work@company.com",
          event_id: "event123"
        ).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:calendar_id] == "work@company.com"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--calendar=work@company.com", "--title=Updated"], "edit")
      end

      # Transparency tests

      def test_updates_event_to_free
        existing_event = build_event(id: "event123", summary: "Meeting")
        updated_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].transparency == "transparent"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--free"], "edit")
      end

      def test_updates_event_to_busy
        existing_event = build_event(id: "event123", summary: "Meeting", transparency: "transparent")
        updated_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].transparency == "opaque"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--busy"], "edit")
      end

      def test_preserves_existing_transparency_when_not_specified
        existing_event = build_event(id: "event123", summary: "Meeting", transparency: "transparent")
        updated_event = build_event(id: "event123", summary: "New Title")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].transparency == "transparent"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--title=New Title"], "edit")
      end

      def test_rejects_free_and_busy_together
        build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).never
        CalendarService.adapter = adapter

        cmd = Edit.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call(["event123", "--free", "--busy"], "edit")
        end

        assert_match(/cannot use --free and --busy together/i, error.message)
      end

      # Timezone option tests

      def test_accepts_timezone_flag
        existing_event = build_event(id: "event123", summary: "Meeting")
        updated_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].timezone == "America/New_York"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--timezone=America/New_York"], "edit")
      end

      def test_preserves_existing_timezone_when_not_specified
        existing_event = build_event(id: "event123", summary: "Meeting", timezone: "America/Chicago")
        updated_event = build_event(id: "event123", summary: "New Title")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].timezone == "America/Chicago"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--title=New Title"], "edit")
      end

      def test_timezone_flag_overrides_existing_timezone
        existing_event = build_event(id: "event123", summary: "Meeting", timezone: "America/Chicago")
        updated_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].timezone == "Europe/London"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--timezone=Europe/London"], "edit")
      end

      # Recurrence option tests

      def test_adds_recurrence_to_event
        existing_event = build_event(id: "event123", summary: "Meeting")
        updated_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].recurrence == ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"]
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--repeat=weekly", "--days=MO,WE,FR"], "edit")
      end

      def test_removes_recurrence_with_repeat_none
        existing_event = build_event(
          id: "event123",
          summary: "Recurring Meeting",
          recurrence: ["RRULE:FREQ=WEEKLY;BYDAY=MO"]
        )
        updated_event = build_event(id: "event123", summary: "Recurring Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].recurrence.nil?
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--repeat=none"], "edit")
      end

      def test_preserves_recurrence_when_not_specified
        existing_event = build_event(
          id: "event123",
          summary: "Weekly Meeting",
          recurrence: ["RRULE:FREQ=WEEKLY;BYDAY=TU"]
        )
        updated_event = build_event(id: "event123", summary: "New Title")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].recurrence == ["RRULE:FREQ=WEEKLY;BYDAY=TU"]
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--title=New Title"], "edit")
      end

      def test_changes_recurrence_pattern
        existing_event = build_event(
          id: "event123",
          summary: "Meeting",
          recurrence: ["RRULE:FREQ=WEEKLY;BYDAY=MO"]
        )
        updated_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].recurrence == ["RRULE:FREQ=DAILY;COUNT=5"]
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--repeat=daily", "--count=5"], "edit")
      end

      def test_rejects_invalid_repeat_frequency_on_edit
        existing_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        CalendarService.adapter = adapter

        cmd = Edit.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call(["event123", "--repeat=biweekly"], "edit")
        end

        assert_match(/invalid recurrence frequency/i, error.message)
      end

      def test_repeat_none_is_case_insensitive
        existing_event = build_event(
          id: "event123",
          summary: "Meeting",
          recurrence: ["RRULE:FREQ=WEEKLY"]
        )
        updated_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].recurrence.nil?
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--repeat=None"], "edit")
      end

      # Color option tests

      def test_updates_event_color_by_name
        existing_event = build_event(id: "event123", summary: "Meeting")
        updated_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].color_id == "7"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--color=peacock"], "edit")
      end

      def test_updates_event_color_by_id
        existing_event = build_event(id: "event123", summary: "Meeting")
        updated_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].color_id == "11"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--color=11"], "edit")
      end

      def test_preserves_existing_color_when_not_specified
        existing_event = build_event(id: "event123", summary: "Meeting", color_id: "11")
        updated_event = build_event(id: "event123", summary: "New Title")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        adapter.expects(:update_event).with { |args|
          args[:event].color_id == "11"
        }.returns(updated_event)
        CalendarService.adapter = adapter

        cmd = Edit.new
        cmd.call(["event123", "--title=New Title"], "edit")
      end

      def test_rejects_invalid_color
        existing_event = build_event(id: "event123", summary: "Meeting")

        adapter = mock_calendar_adapter
        adapter.expects(:get_event).returns(existing_event)
        CalendarService.adapter = adapter

        cmd = Edit.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call(["event123", "--color=magenta"], "edit")
        end

        assert_match(/unknown color/i, error.message)
      end

      # Error handling tests

      def test_handles_event_not_found
        adapter = mock_calendar_adapter
        adapter.expects(:get_event).raises(StandardError.new("Event not found"))
        CalendarService.adapter = adapter

        cmd = Edit.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call(["nonexistent123"], "edit")
        end

        assert_match(/not found|error/i, error.message)
      end

      # Authentication tests

      def test_requires_authentication
        token_path = File.join(@temp_dir, "tokens.json")
        FileUtils.rm_f(token_path)
        Auth.reset_adapter!

        cmd = Edit.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call(["event123", "--title=New"], "edit")
        end

        assert_match(/not authenticated|run.*init/i, error.message)
      end

      # Help text test

      def test_has_help_text
        help = Edit.help.to_s
        assert_match(/edit|update.*event/i, help)
        assert_match(/event.*id/i, help)
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
        location: nil,
        description: nil,
        color_id: nil,
        timezone: nil,
        recurrence: nil,
        transparency: nil
      )
        start_time ||= Time.now + 3600
        end_time ||= start_time + 3600

        Rcal::Event.new(
          id: id,
          summary: summary,
          start_time: start_time,
          end_time: end_time,
          location: location,
          description: description,
          color_id: color_id,
          timezone: timezone,
          recurrence: recurrence,
          transparency: transparency
        )
      end
    end
  end
end
