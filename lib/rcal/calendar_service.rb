require "json"
require "yaml"
require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require_relative "adapters/calendar/google"
require_relative "auth"
require_relative "config"

module Rcal
  class CalendarService
    class << self
      def list_calendars
        adapter.list_calendars
      end

      def get_calendar(calendar_id:)
        adapter.get_calendar(calendar_id: calendar_id)
      end

      def list_events(calendar_id:, time_min:, time_max:)
        adapter.list_events(
          calendar_id: calendar_id,
          time_min: time_min,
          time_max: time_max
        )
      end

      def get_event(calendar_id:, event_id:)
        adapter.get_event(calendar_id: calendar_id, event_id: event_id)
      end

      def create_event(calendar_id:, event:)
        adapter.create_event(calendar_id: calendar_id, event: event)
      end

      def update_event(calendar_id:, event_id:, event:)
        adapter.update_event(calendar_id: calendar_id, event_id: event_id, event: event)
      end

      def delete_event(calendar_id:, event_id:)
        adapter.delete_event(calendar_id: calendar_id, event_id: event_id)
      end

      def quick_add(calendar_id:, text:)
        adapter.quick_add(calendar_id: calendar_id, text: text)
      end

      def adapter
        @adapter ||= default_adapter
      end

      attr_writer :adapter

      def reset_adapter!
        @adapter = nil
      end

      private

      def default_adapter
        Adapters::Calendar::Google.new(service: build_calendar_service)
      end

      def build_calendar_service
        service = Google::Apis::CalendarV3::CalendarService.new
        service.authorization = load_credentials
        service
      end

      # Load credentials via UserAuthorizer so refreshed tokens are
      # automatically persisted back to google_tokens.yaml via the
      # on_refresh callback (see UserAuthorizer#monitor_credentials).
      def load_credentials
        client_creds = Auth.load_client_credentials
        return nil if client_creds.nil?

        token_store = Google::Auth::Stores::FileTokenStore.new(
          file: Auth.token_path
        )

        client_id = Google::Auth::ClientId.new(
          client_creds["client_id"],
          client_creds["client_secret"]
        )

        authorizer = Google::Auth::UserAuthorizer.new(
          client_id,
          Adapters::Auth::Google::SCOPES,
          token_store
        )

        authorizer.get_credentials("default")
      end
    end
  end
end
