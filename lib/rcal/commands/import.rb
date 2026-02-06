require "rcal"
require_relative "../auth"
require_relative "../calendar_service"
require_relative "../ics_parser"
require_relative "../presenters/event_presenter"

module Rcal
  module Commands
    class Import < Rcal::Command
      def self.help
        <<~HELP
          Import events from an ICS file.

          Usage: rcal import FILE [OPTIONS]

          Arguments:
            FILE              Path to the .ics file to import

          Options:
            --calendar=ID     Calendar to import events to (default: primary)

          Examples:
            rcal import ~/Downloads/invite.ics
            rcal import meeting.ics --calendar=work@company.com
        HELP
      end

      def run(args, _name)
        ensure_authenticated!

        options = parse_options(args)
        file_path = extract_file_path(args)

        validate_file_path!(file_path)

        events = parse_ics_file(file_path)

        if events.empty?
          puts "No events found in #{File.basename(file_path)}"
          return
        end

        import_events(events, options[:calendar])
        display_results(events, file_path)
      end

      private

      VALUE_OPTIONS = %w[calendar].freeze

      def parse_options(args)
        options = {calendar: "primary"}

        args.each do |arg|
          case parse_arg(arg)
          in {option:, value:} if VALUE_OPTIONS.include?(option)
            options[option.to_sym] = value
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

      def extract_file_path(args)
        args.find { |arg| !arg.start_with?("--") }
      end

      def validate_file_path!(file_path)
        if file_path.nil? || file_path.empty?
          raise CLI::Kit::Abort, "File path is required.\n" \
            "Usage: rcal import ~/Downloads/invite.ics"
        end

        unless File.exist?(file_path)
          raise CLI::Kit::Abort, "File not found: #{file_path}"
        end
      end

      def parse_ics_file(file_path)
        IcsParser.parse_file(file_path)
      rescue Rcal::ParseError => e
        raise CLI::Kit::Abort, "Failed to parse ICS file: #{e.message}"
      end

      def import_events(events, calendar_id)
        events.map do |event|
          CalendarService.create_event(calendar_id: calendar_id, event: event)
        end
      end

      def display_results(events, file_path)
        count = events.length
        noun = (count == 1) ? "event" : "events"

        puts CLI::UI.fmt("{{v}} Imported #{count} #{noun} from #{File.basename(file_path)}")
        puts ""

        events.each do |event|
          presenter = Presenters::EventPresenter.new(event)
          puts "  #{presenter.to_s_with_date}"
        end
      end

      def ensure_authenticated!
        unless Auth.authenticated?
          raise CLI::Kit::Abort, "Not authenticated. Run 'rcal init' first."
        end
      end
    end
  end
end
