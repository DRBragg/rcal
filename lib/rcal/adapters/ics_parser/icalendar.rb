require "icalendar"
require_relative "base"
require_relative "../../models/event"
require_relative "../../errors"

module Rcal
  module Adapters
    module IcsParser
      class Icalendar < Base
        def parse(content)
          calendars = ::Icalendar::Calendar.parse(content)
          raise Rcal::ParseError, "Invalid ICS content" if calendars.empty?

          extract_events(calendars)
        rescue ::Icalendar::Parser::ParseError => e
          raise Rcal::ParseError, "Failed to parse ICS: #{e.message}"
        end

        def parse_file(path)
          raise Rcal::ParseError, "File not found: #{path}" unless File.exist?(path)

          content = File.read(path)
          parse(content)
        end

        private

        def extract_events(calendars)
          calendars.flat_map do |calendar|
            calendar.events.map { |ics_event| build_event(ics_event) }
          end
        end

        def build_event(ics_event)
          start_time, all_day = parse_datetime(ics_event.dtstart)
          end_time, = parse_datetime(ics_event.dtend)

          Rcal::Event.new(
            summary: ics_event.summary&.to_s,
            description: presence(ics_event.description&.to_s),
            location: presence(ics_event.location&.to_s),
            start_time: start_time,
            end_time: end_time,
            all_day: all_day
          )
        end

        def presence(value)
          return nil if value.nil? || value.empty?
          value
        end

        def parse_datetime(dt)
          return [Time.now, false] if dt.nil?

          case dt
          when ::Icalendar::Values::Date
            [dt.to_time, true]
          when ::Icalendar::Values::DateTime
            [dt.to_time, false]
          else
            [dt.to_time, false]
          end
        end
      end
    end
  end
end
