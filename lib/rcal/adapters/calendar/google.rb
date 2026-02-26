require "time"
require "google/apis/calendar_v3"
require_relative "base"
require_relative "../../models/calendar"
require_relative "../../models/event"

module Rcal
  module Adapters
    module Calendar
      class Google < Base
        def initialize(service:)
          @service = service
        end

        def list_calendars
          response = @service.list_calendar_lists
          items = response.items || []

          items.map { |cal| build_calendar(cal) }
        end

        def list_events(calendar_id:, time_min:, time_max:)
          response = @service.list_events(
            calendar_id,
            time_min: time_min.iso8601,
            time_max: time_max.iso8601,
            single_events: true,
            order_by: "startTime"
          )

          items = response.items || []

          items.map { |evt| build_event(evt, calendar_id: calendar_id) }
        end

        def get_event(calendar_id:, event_id:)
          google_event = @service.get_event(calendar_id, event_id)
          build_event(google_event, calendar_id: calendar_id)
        end

        def create_event(calendar_id:, event:)
          google_event = build_google_event(event)
          response = @service.insert_event(calendar_id, google_event)
          build_event(response, calendar_id: calendar_id)
        end

        def update_event(calendar_id:, event_id:, event:)
          google_event = build_google_event(event)
          response = @service.update_event(calendar_id, event_id, google_event)
          build_event(response, calendar_id: calendar_id)
        end

        def delete_event(calendar_id:, event_id:)
          @service.delete_event(calendar_id, event_id)
          true
        end

        def quick_add(calendar_id:, text:)
          response = @service.quick_add_event(calendar_id, text)
          build_event(response, calendar_id: calendar_id)
        end

        private

        def build_calendar(google_calendar)
          Rcal::Calendar.new(
            id: google_calendar.id,
            name: google_calendar.summary,
            description: google_calendar.description,
            timezone: google_calendar.time_zone,
            color: google_calendar.background_color,
            access_role: google_calendar.access_role,
            primary: google_calendar.primary || false,
            selected: google_calendar.selected || false
          )
        end

        def build_event(google_event, calendar_id:)
          start_time, all_day = parse_event_time(google_event.start)
          end_time, = parse_event_time(google_event.end)

          Rcal::Event.new(
            id: google_event.id,
            summary: google_event.summary,
            description: google_event.description,
            location: google_event.location,
            start_time: start_time,
            end_time: end_time,
            all_day: all_day,
            calendar_id: calendar_id,
            transparency: google_event.transparency,
            recurrence: google_event.recurrence,
            recurring_event_id: google_event.recurring_event_id,
            response_status: extract_self_response_status(google_event.attendees),
            attendees: build_attendees(google_event.attendees),
            timezone: google_event.start&.time_zone,
            color_id: google_event.color_id
          )
        end

        def parse_event_time(time_obj)
          return [Time.now, false] if time_obj.nil?

          if time_obj.date_time
            # Google returns DateTime; convert to Time for consistent arithmetic
            [time_obj.date_time.to_time, false]
          elsif time_obj.date
            [time_obj.date.to_time, true]
          else
            [Time.now, false]
          end
        end

        def extract_self_response_status(attendees)
          return nil if attendees.nil?

          self_attendee = attendees.find { |a| a.self }
          self_attendee&.response_status
        end

        def build_attendees(google_attendees)
          return nil if google_attendees.nil?

          google_attendees.map do |attendee|
            {
              email: attendee.email,
              response_status: attendee.response_status,
              self: attendee.self || false,
              resource: attendee.resource || false
            }
          end
        end

        def build_google_event(event)
          google_event = ::Google::Apis::CalendarV3::Event.new(
            summary: event.summary,
            description: event.description,
            location: event.location,
            color_id: event.color_id
          )

          if event.all_day?
            google_event.start = ::Google::Apis::CalendarV3::EventDateTime.new(
              date: event.start_time.to_date.to_s
            )
            google_event.end = ::Google::Apis::CalendarV3::EventDateTime.new(
              date: event.end_time.to_date.to_s
            )
          else
            google_event.start = ::Google::Apis::CalendarV3::EventDateTime.new(
              date_time: event.start_time.iso8601
            )
            google_event.end = ::Google::Apis::CalendarV3::EventDateTime.new(
              date_time: event.end_time.iso8601
            )
          end

          google_event
        end
      end
    end
  end
end
