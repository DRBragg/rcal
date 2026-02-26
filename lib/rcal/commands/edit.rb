require "rcal"
require_relative "../auth"
require_relative "../calendar_service"
require_relative "../date_parser"
require_relative "../duration_parser"
require_relative "../models/event"
require_relative "../presenters/event_presenter"
require_relative "../color_map"
require_relative "../timezone_resolver"
require_relative "../recurrence_builder"

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
            --color=COLOR       New event color (name or ID). Run 'rcal colors' to see options
            --timezone=TZ       IANA timezone (e.g., "America/New_York")
            --free              Mark event as free (does not block calendar)
            --busy              Mark event as busy (blocks calendar)

          Recurrence:
            --repeat=FREQ       Change recurrence: daily, weekly, monthly, yearly, or "none" to remove
            --days=DAYS         Days of week (e.g., "MO,WE,FR" or "Monday,Wed"). Requires --repeat
            --count=N           Number of occurrences. Cannot be used with --until
            --until=DATE        End date for recurrence. Cannot be used with --count
            --interval=N        Repeat every N periods (e.g., --repeat=weekly --interval=2 = biweekly)

          Examples:
            rcal edit abc123 --title="Updated Meeting"
            rcal edit abc123 --when="tomorrow 4pm" --duration=30m
            rcal edit abc123 --location="Room 202" --calendar=work@company.com
            rcal edit abc123 --color=peacock
            rcal edit abc123 --free
            rcal edit abc123 --busy
            rcal edit abc123 --repeat=weekly --days=MO,WE,FR
            rcal edit abc123 --repeat=none
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

      VALUE_OPTIONS = %w[title when duration location description calendar color timezone repeat days count until interval].freeze
      FLAG_OPTIONS = {"free" => :free, "busy" => :busy}.freeze

      def parse_options(args)
        options = {calendar: "primary"}

        args.each do |arg|
          case parse_arg(arg)
          in {option:, value:} if VALUE_OPTIONS.include?(option)
            options[option.tr("-", "_").to_sym] = value
          in {flag:} if FLAG_OPTIONS.key?(flag)
            options[FLAG_OPTIONS[flag]] = true
          else
            nil
          end
        end

        validate_transparency_options!(options)

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

      def validate_transparency_options!(options)
        if options[:free] && options[:busy]
          raise CLI::Kit::Abort, "Cannot use --free and --busy together."
        end
      end

      def resolve_transparency(options, existing_event)
        if options[:free]
          "transparent"
        elsif options[:busy]
          "opaque"
        else
          existing_event.transparency
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
        color_id = options.key?(:color) ? resolve_color(options[:color]) : existing_event.color_id
        timezone = resolve_timezone(options[:timezone], existing_event.timezone, options[:calendar])
        recurrence = resolve_recurrence(options, existing_event)
        transparency = resolve_transparency(options, existing_event)

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
          calendar_id: existing_event.calendar_id,
          color_id: color_id,
          timezone: timezone,
          recurrence: recurrence,
          transparency: transparency
        )
      end

      def resolve_recurrence(options, existing_event)
        return existing_event.recurrence unless options[:repeat]

        # --repeat=none removes recurrence
        return nil if options[:repeat].downcase == "none"

        build_recurrence(options)
      end

      def build_recurrence(options)
        RecurrenceBuilder.build(
          freq: options[:repeat],
          days: options[:days],
          count: options[:count],
          until_date: options[:until],
          interval: options[:interval]
        )
      rescue Rcal::Error => e
        raise CLI::Kit::Abort, e.message
      end

      def resolve_timezone(timezone_input, existing_timezone, calendar_id)
        # Explicit flag wins, then preserve existing event timezone, then resolve from calendar/system
        timezone_input || existing_timezone || TimezoneResolver.resolve(calendar_id: calendar_id)
      end

      def resolve_color(color_input)
        return nil if color_input.nil?

        ColorMap.resolve(color_input)
      rescue Rcal::Error => e
        raise CLI::Kit::Abort, e.message
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
