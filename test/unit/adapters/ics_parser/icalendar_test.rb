require "test_helper"
require "rcal/adapters/ics_parser/icalendar"
require "rcal/models/event"

module Rcal
  module Adapters
    module IcsParser
      class IcalendarTest < Minitest::Test
        def setup
          @parser = Icalendar.new
          @fixtures_path = File.expand_path("../../../../fixtures", __FILE__)
        end

        def test_parses_single_event_from_file
          file_path = File.join(@fixtures_path, "single_event.ics")

          events = @parser.parse_file(file_path)

          assert_equal 1, events.length
          event = events.first
          assert_equal "Team Meeting", event.summary
          assert_equal "Discuss project updates", event.description
          assert_equal "Conference Room A", event.location
        end

        def test_parses_event_times
          file_path = File.join(@fixtures_path, "single_event.ics")

          events = @parser.parse_file(file_path)
          event = events.first

          assert_equal Time.utc(2024, 1, 15, 14, 0, 0), event.start_time.utc
          assert_equal Time.utc(2024, 1, 15, 15, 0, 0), event.end_time.utc
          refute event.all_day?
        end

        def test_parses_all_day_event
          file_path = File.join(@fixtures_path, "all_day_event.ics")

          events = @parser.parse_file(file_path)
          event = events.first

          assert_equal "Company Holiday", event.summary
          assert event.all_day?
          assert_equal Date.new(2024, 1, 15), event.start_time.to_date
        end

        def test_parses_multiple_events
          file_path = File.join(@fixtures_path, "multiple_events.ics")

          events = @parser.parse_file(file_path)

          assert_equal 2, events.length
          assert_equal "Morning Standup", events[0].summary
          assert_equal "Afternoon Review", events[1].summary
        end

        def test_parse_string_content
          ics_content = <<~ICS
            BEGIN:VCALENDAR
            VERSION:2.0
            BEGIN:VEVENT
            DTSTART:20240120T100000Z
            DTEND:20240120T110000Z
            SUMMARY:Quick Meeting
            END:VEVENT
            END:VCALENDAR
          ICS

          events = @parser.parse(ics_content)

          assert_equal 1, events.length
          assert_equal "Quick Meeting", events.first.summary
        end

        def test_returns_empty_array_for_calendar_with_no_events
          ics_content = <<~ICS
            BEGIN:VCALENDAR
            VERSION:2.0
            PRODID:-//Test//Test//EN
            END:VCALENDAR
          ICS

          events = @parser.parse(ics_content)

          assert_equal [], events
        end

        def test_raises_error_for_invalid_ics
          assert_raises(Rcal::ParseError) do
            @parser.parse("not valid ics content")
          end
        end

        def test_raises_error_for_missing_file
          assert_raises(Rcal::ParseError) do
            @parser.parse_file("/nonexistent/file.ics")
          end
        end

        def test_returns_rcal_event_objects
          file_path = File.join(@fixtures_path, "single_event.ics")

          events = @parser.parse_file(file_path)

          assert_instance_of Rcal::Event, events.first
        end

        def test_handles_event_without_optional_fields
          ics_content = <<~ICS
            BEGIN:VCALENDAR
            VERSION:2.0
            BEGIN:VEVENT
            DTSTART:20240120T100000Z
            DTEND:20240120T110000Z
            SUMMARY:Minimal Event
            END:VEVENT
            END:VCALENDAR
          ICS

          events = @parser.parse(ics_content)
          event = events.first

          assert_equal "Minimal Event", event.summary
          assert_nil event.description
          assert_nil event.location
        end
      end
    end
  end
end
