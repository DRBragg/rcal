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
    class Add < Rcal::Command
      DEFAULT_DURATION = 3600 # 1 hour in seconds

      def self.help
        <<~HELP
          Create a new calendar event.

          Usage: rcal add [OPTIONS]

          Required:
            --title=TEXT        Event title
            --when=DATETIME     Start time (natural language: "tomorrow 3pm", "monday at 10am")

          Optional:
            --duration=DURATION Duration (e.g., "30m", "1h", "1h30m"). Default: 1h
            --location=TEXT     Event location
            --description=TEXT  Event description
            --calendar=ID       Calendar to add event to (default: primary)
            --color=COLOR       Event color (name or ID). Run 'rcal colors' to see options
            --timezone=TZ       IANA timezone (e.g., "America/New_York"). Default: calendar's timezone
            --all-day           Create an all-day event
            --free              Mark event as free (default: busy)

          Recurrence:
            --repeat=FREQ       Recurrence frequency: daily, weekly, monthly, yearly
            --days=DAYS         Days of week (e.g., "MO,WE,FR" or "Monday,Wed"). Requires --repeat
            --count=N           Number of occurrences. Cannot be used with --until
            --until=DATE        End date for recurrence. Cannot be used with --count
            --interval=N        Repeat every N periods (e.g., --repeat=weekly --interval=2 = biweekly)

          Examples:
            rcal add --title="Team Meeting" --when="tomorrow 3pm"
            rcal add --title="Lunch" --when="friday noon" --duration=1h --location="Cafe"
            rcal add --title="Vacation" --when="monday" --all-day
            rcal add --title="Important" --when="tomorrow 9am" --color=tomato
            rcal add --title="Focus Time" --when="tomorrow 2pm" --duration=2h --free
            rcal add --title="Standup" --when="monday 9am" --repeat=weekly --days=MO,WE,FR
            rcal add --title="1:1" --when="monday 2pm" --repeat=weekly --interval=2 --count=10
        HELP
      end

      def run(args, _name)
        ensure_authenticated!

        options = parse_options(args)
        validate_options!(options)

        event = build_event(options)

        created_event = CalendarService.create_event(
          calendar_id: options[:calendar],
          event: event
        )

        display_created_event(created_event)
      end

      private

      VALUE_OPTIONS = %w[title when duration location description calendar color timezone repeat days count until interval].freeze
      FLAG_OPTIONS = {"all-day" => :all_day, "free" => :free}.freeze

      def parse_options(args)
        options = {calendar: "primary", all_day: false}

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

        options
      end

      def parse_arg(arg)
        case arg
        when /^--([^=]+)=(.+)$/ then {option: $1, value: $2}
        when /^--([^=]+)$/ then {flag: $1}
        else {positional: arg}
        end
      end

      def validate_options!(options)
        if options[:title].nil? || options[:title].empty?
          raise CLI::Kit::Abort, "Title is required.\n" \
            "Usage: rcal add --title=\"Meeting\" --when=\"tomorrow 3pm\""
        end

        if options[:when].nil? || options[:when].empty?
          raise CLI::Kit::Abort, "When is required.\n" \
            "Usage: rcal add --title=\"Meeting\" --when=\"tomorrow 3pm\""
        end

        validate_recurrence_options!(options)
      end

      def validate_recurrence_options!(options)
        recurrence_modifiers = %i[days count until interval]
        has_modifiers = recurrence_modifiers.any? { |key| options[key] }

        if has_modifiers && options[:repeat].nil?
          raise CLI::Kit::Abort,
            "Recurrence modifiers (--days, --count, --until, --interval) require --repeat.\n" \
            "Usage: rcal add --title=\"Meeting\" --when=\"monday 9am\" --repeat=weekly --days=MO,WE,FR"
        end
      end

      def build_event(options)
        start_time = parse_start_time(options[:when])
        duration = parse_duration(options[:duration])
        end_time = calculate_end_time(start_time, duration, options[:all_day])
        timezone = resolve_timezone(options[:timezone], options[:calendar])
        recurrence = build_recurrence(options)

        Event.new(
          summary: options[:title],
          start_time: start_time,
          end_time: end_time,
          location: options[:location],
          description: options[:description],
          all_day: options[:all_day],
          color_id: resolve_color(options[:color]),
          timezone: timezone,
          recurrence: recurrence,
          transparency: options[:free] ? "transparent" : nil
        )
      end

      def parse_start_time(when_text)
        DateParser.parse(when_text)
      rescue Rcal::ParseError => e
        raise CLI::Kit::Abort, "Could not parse date: #{e.message}"
      end

      def parse_duration(duration_text)
        return DEFAULT_DURATION if duration_text.nil?

        DurationParser.parse(duration_text)
      rescue Rcal::ParseError => e
        raise CLI::Kit::Abort, "Could not parse duration: #{e.message}"
      end

      def calculate_end_time(start_time, duration, all_day)
        if all_day
          # All-day events end on the next day
          (start_time.to_date + 1).to_time
        else
          start_time + duration
        end
      end

      def build_recurrence(options)
        return nil unless options[:repeat]

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

      def resolve_timezone(timezone_input, calendar_id)
        TimezoneResolver.resolve(explicit: timezone_input, calendar_id: calendar_id)
      end

      def resolve_color(color_input)
        return nil if color_input.nil?

        ColorMap.resolve(color_input)
      rescue Rcal::Error => e
        raise CLI::Kit::Abort, e.message
      end

      def display_created_event(event)
        presenter = Presenters::EventPresenter.new(event)
        puts CLI::UI.fmt("{{v}} Event created: #{presenter.to_s_with_date}")
        puts CLI::UI.fmt("    ID: {{cyan:#{event.id}}}")
      end

      def ensure_authenticated!
        unless Auth.authenticated?
          raise CLI::Kit::Abort, "Not authenticated. Run 'rcal init' first."
        end
      end
    end
  end
end
