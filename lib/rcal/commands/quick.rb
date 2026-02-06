require "rcal"
require_relative "../auth"
require_relative "../calendar_service"
require_relative "../presenters/event_presenter"

module Rcal
  module Commands
    class Quick < Rcal::Command
      def self.help
        <<~HELP
          Quickly add an event using natural language.

          Usage: rcal quick "EVENT TEXT" [OPTIONS]

          Examples:
            rcal quick "Lunch with Sarah tomorrow noon"
            rcal quick "Team standup every weekday 10am"
            rcal quick "Dentist appointment Friday 2pm" --calendar=personal

          Options:
            --calendar=ID     Calendar to add event to (default: primary)
        HELP
      end

      def run(args, _name)
        ensure_authenticated!

        options = parse_options(args)
        text = extract_text(args)

        validate_text!(text)

        event = CalendarService.quick_add(
          calendar_id: options[:calendar],
          text: text
        )

        display_created_event(event)
      end

      private

      def parse_options(args)
        options = {calendar: "primary"}

        args.each do |arg|
          if arg =~ /^--calendar=(.+)$/
            options[:calendar] = ::Regexp.last_match(1)
          end
        end

        options
      end

      def extract_text(args)
        text_args = args.reject { |arg| arg.start_with?("--") }
        text_args.join(" ")
      end

      def validate_text!(text)
        if text.nil? || text.strip.empty?
          raise CLI::Kit::Abort, "Event text is required.\n" \
            "Usage: rcal quick \"Meeting tomorrow at 3pm\""
        end
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
