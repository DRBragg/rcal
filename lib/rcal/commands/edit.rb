require "rcal"
require_relative "../auth"
require_relative "../calendar_service"
require_relative "../date_parser"
require_relative "../duration_parser"
require_relative "../models/event"
require_relative "../presenters/event_presenter"

module Rcal
  module Commands
    class Edit < Rcal::Command
      def self.help
        <<~HELP
          Edit an existing calendar event.

          Usage: rcal edit EVENT_ID [OPTIONS]

          Required:
            EVENT_ID            The ID of the event to edit

          Optional:
            --title=TEXT        New event title
            --when=DATETIME     New start time (natural language)
            --duration=DURATION New duration (e.g., "30m", "1h")
            --location=TEXT     New event location
            --description=TEXT  New event description
            --calendar=ID       Calendar containing the event (default: primary)

          Examples:
            rcal edit abc123 --title="Updated Meeting"
            rcal edit abc123 --when="tomorrow 4pm" --duration=30m
            rcal edit abc123 --location="Room 202" --calendar=work@company.com
        HELP
      end

      def run(args, _name)
        ensure_authenticated!

        options = parse_options(args)
        event_id = extract_event_id(args)

        validate_event_id!(event_id)

        existing_event = fetch_event(options[:calendar], event_id)
        updated_event = apply_changes(existing_event, options)

        result = CalendarService.update_event(
          calendar_id: options[:calendar],
          event_id: event_id,
          event: updated_event
        )

        display_updated_event(result)
      end

      private

      VALUE_OPTIONS = %w[title when duration location description calendar].freeze

      def parse_options(args)
        options = {calendar: "primary"}

        args.each do |arg|
          case parse_arg(arg)
          in {option:, value:} if VALUE_OPTIONS.include?(option)
            options[option.tr("-", "_").to_sym] = value
          else
            nil
          end
        end

        options
      end

      def parse_arg(arg)
        case arg
        when /^--([^=]+)=(.+)$/ then {option: $1, value: $2}
        when /^--([^=]+)$/ then {flag: $1}
        else {positional: arg}
        end
      end

      def extract_event_id(args)
        args.find { |arg| !arg.start_with?("--") }
      end

      def validate_event_id!(event_id)
        if event_id.nil? || event_id.empty?
          raise CLI::Kit::Abort, "Event ID is required.\n" \
            "Usage: rcal edit EVENT_ID --title=\"New Title\""
        end
      end

      def fetch_event(calendar_id, event_id)
        CalendarService.get_event(calendar_id: calendar_id, event_id: event_id)
      rescue => e
        raise CLI::Kit::Abort, "Could not find event: #{e.message}"
      end

      def apply_changes(existing_event, options)
        summary = options[:title] || existing_event.summary
        location = options.key?(:location) ? options[:location] : existing_event.location
        description = options.key?(:description) ? options[:description] : existing_event.description

        start_time = if options[:when]
          parse_start_time(options[:when])
        else
          existing_event.start_time
        end

        end_time = if options[:duration]
          duration = parse_duration(options[:duration])
          start_time + duration
        elsif options[:when]
          # Keep same duration if only time changed
          duration = existing_event.end_time - existing_event.start_time
          start_time + duration
        else
          existing_event.end_time
        end

        Event.new(
          id: existing_event.id,
          summary: summary,
          start_time: start_time,
          end_time: end_time,
          location: location,
          description: description,
          all_day: existing_event.all_day?,
          calendar_id: existing_event.calendar_id
        )
      end

      def parse_start_time(when_text)
        DateParser.parse(when_text)
      rescue Rcal::ParseError => e
        raise CLI::Kit::Abort, "Could not parse date: #{e.message}"
      end

      def parse_duration(duration_text)
        DurationParser.parse(duration_text)
      rescue Rcal::ParseError => e
        raise CLI::Kit::Abort, "Could not parse duration: #{e.message}"
      end

      def display_updated_event(event)
        presenter = Presenters::EventPresenter.new(event)
        puts CLI::UI.fmt("{{v}} Event updated: #{presenter.to_s_with_date}")
      end

      def ensure_authenticated!
        unless Auth.authenticated?
          raise CLI::Kit::Abort, "Not authenticated. Run 'rcal init' first."
        end
      end
    end
  end
end
