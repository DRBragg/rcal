require "test_helper"
require "rcal/commands/edit"
require "rcal/models/event"
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

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:get_event).with(
          calendar_id: "primary",
          event_id: "event123"
        ).returns(existing_event)
        mock_adapter.expects(:update_event).returns(updated_event)
        CalendarService.adapter = mock_adapter

        cmd = Edit.new
        cmd.call(["event123", "--title=Updated Meeting"], "edit")
      end

      def test_updates_event_title
        existing_event = build_event(id: "event123", summary: "Original")
        updated_event = build_event(id: "event123", summary: "New Title")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:get_event).returns(existing_event)
        mock_adapter.expects(:update_event).with { |args|
          args[:event].summary == "New Title"
        }.returns(updated_event)
        CalendarService.adapter = mock_adapter

        cmd = Edit.new
        cmd.call(["event123", "--title=New Title"], "edit")

        assert_match(/updated/i, captured_output)
      end

      def test_updates_event_location
        existing_event = build_event(id: "event123", summary: "Meeting")
        updated_event = build_event(id: "event123", summary: "Meeting", location: "Room 101")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:get_event).returns(existing_event)
        mock_adapter.expects(:update_event).with { |args|
          args[:event].location == "Room 101"
        }.returns(updated_event)
        CalendarService.adapter = mock_adapter

        cmd = Edit.new
        cmd.call(["event123", "--location=Room 101"], "edit")
      end

      def test_updates_event_description
        existing_event = build_event(id: "event123", summary: "Meeting")
        updated_event = build_event(id: "event123", summary: "Meeting")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:get_event).returns(existing_event)
        mock_adapter.expects(:update_event).with { |args|
          args[:event].description == "New description"
        }.returns(updated_event)
        CalendarService.adapter = mock_adapter

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

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:get_event).returns(existing_event)
        mock_adapter.expects(:update_event).returns(updated_event)
        CalendarService.adapter = mock_adapter

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

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:get_event).returns(existing_event)
        mock_adapter.expects(:update_event).with { |args|
          # Title changes, but location and description should be preserved
          args[:event].summary == "New Title" &&
            args[:event].location == "Original Location" &&
            args[:event].description == "Original Description"
        }.returns(updated_event)
        CalendarService.adapter = mock_adapter

        cmd = Edit.new
        cmd.call(["event123", "--title=New Title"], "edit")
      end

      def test_accepts_calendar_flag
        existing_event = build_event(id: "event123", summary: "Meeting")
        updated_event = build_event(id: "event123", summary: "Updated")

        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:get_event).with(
          calendar_id: "work@company.com",
          event_id: "event123"
        ).returns(existing_event)
        mock_adapter.expects(:update_event).with { |args|
          args[:calendar_id] == "work@company.com"
        }.returns(updated_event)
        CalendarService.adapter = mock_adapter

        cmd = Edit.new
        cmd.call(["event123", "--calendar=work@company.com", "--title=Updated"], "edit")
      end

      # Error handling tests

      def test_handles_event_not_found
        mock_adapter = mock("calendar_adapter")
        mock_adapter.expects(:get_event).raises(StandardError.new("Event not found"))
        CalendarService.adapter = mock_adapter

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

      def build_event(
        id:,
        summary:,
        start_time: nil,
        end_time: nil,
        location: nil,
        description: nil
      )
        start_time ||= Time.now + 3600
        end_time ||= start_time + 3600

        Rcal::Event.new(
          id: id,
          summary: summary,
          start_time: start_time,
          end_time: end_time,
          location: location,
          description: description
        )
      end
    end
  end
end
