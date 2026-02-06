require "rcal"
require_relative "../auth"
require_relative "../calendar_service"
require_relative "../formatters/agenda"
require_relative "../predicate_collection"
require_relative "../date_parser"

module Rcal
  module Commands
    class Agenda < Rcal::Command
      def self.help
        <<~HELP
          Show upcoming events from your calendar.

          Usage: rcal agenda [START] [END] [OPTIONS]

          Arguments:
            START     Start date (default: today). Supports natural language like "tomorrow", "next monday"
            END       End date (optional). If not provided, shows events for START only

          Options:
            --calendar=ID     Calendar to show (default: primary)
            --days=N          Show N days starting from START
            --must-be=PRED    Only show events matching predicates (comma-separated)
            --must-not-be=PRED  Hide events matching predicates (comma-separated)
            --hide-declined   Hide events you've declined
            --show-ids        Show event IDs (useful for editing events)

          Available predicates:
            accepted, declined, awaiting, tentative
            all_day, past, current, future
            one_on_one, busy, recurring, commitment
        HELP
      end

      def run(args, _name)
        ensure_authenticated!

        options = parse_options(args)
        positional_args = args.reject { |a| a.start_with?("--") }

        date_range = determine_date_range(positional_args, options)
        predicates = build_predicates(options)

        events = fetch_events(options[:calendar], date_range)
        filtered_events = apply_predicates(events, predicates)

        formatter = Rcal::Formatters::Agenda.new(
          filtered_events,
          date_range: date_range,
          hide_declined: options[:hide_declined],
          show_ids: options[:show_ids]
        )

        puts formatter.format
      end

      private

      def parse_options(args)
        options = {
          calendar: "primary",
          days: nil,
          must_be: [],
          must_not_be: [],
          hide_declined: false,
          show_ids: false
        }

        args.each do |arg|
          case arg
          when /^--calendar=(.+)$/
            options[:calendar] = ::Regexp.last_match(1)
          when /^--days=(\d+)$/
            options[:days] = ::Regexp.last_match(1).to_i
          when /^--must-be=(.+)$/
            options[:must_be] = ::Regexp.last_match(1).split(",").map(&:strip)
          when /^--must-not-be=(.+)$/
            options[:must_not_be] = ::Regexp.last_match(1).split(",").map(&:strip)
          when "--hide-declined"
            options[:hide_declined] = true
          when "--show-ids"
            options[:show_ids] = true
          end
        end

        options
      end

      def determine_date_range(positional_args, options)
        start_date = if positional_args.empty?
          Date.today
        else
          parse_date(positional_args[0]) || Date.today
        end

        end_date = if options[:days]
          start_date + options[:days] - 1
        elsif positional_args.length >= 2
          parse_date(positional_args[1]) || start_date
        else
          start_date
        end

        start_date..end_date
      end

      def parse_date(input)
        Rcal::DateParser.parse(input)&.to_date
      end

      def build_predicates(options)
        Rcal::PredicateCollection.new(
          must_be: options[:must_be],
          must_not_be: options[:must_not_be]
        )
      rescue Rcal::InvalidPredicateError => e
        raise CLI::Kit::Abort, "Invalid predicate: #{e.message}"
      end

      def fetch_events(calendar_id, date_range)
        time_min = date_range.first.to_time
        time_max = (date_range.last + 1).to_time # Include all of the last day

        CalendarService.list_events(
          calendar_id: calendar_id,
          time_min: time_min,
          time_max: time_max
        )
      end

      def apply_predicates(events, predicates)
        predicates.filter(events)
      end

      def ensure_authenticated!
        unless Auth.authenticated?
          raise CLI::Kit::Abort, "Not authenticated. Run 'rcal init' first."
        end
      end
    end
  end
end
