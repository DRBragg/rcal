require "rcal"
require_relative "../auth"
require_relative "../calendar_service"
require_relative "../presenters/calendar_presenter"

module Rcal
  module Commands
    class List < Rcal::Command
      def self.help
        <<~HELP
          List all calendars accessible to your account.

          Usage: rcal list

          Displays calendar name, ID, and access role for each calendar.
          Use the calendar ID with --calendar flag in other commands.

          Examples:
            rcal list
            rcal agenda --calendar=work@company.com
        HELP
      end

      def run(_args, _name)
        ensure_authenticated!

        calendars = CalendarService.list_calendars

        if calendars.empty?
          puts "No calendars found."
          return
        end

        calendars.each do |calendar|
          presenter = Rcal::Presenters::CalendarPresenter.new(calendar)
          puts presenter
        end
      end

      private

      def ensure_authenticated!
        unless Auth.authenticated?
          raise CLI::Kit::Abort, "Not authenticated. Run 'rcal init' first."
        end
      end
    end
  end
end
