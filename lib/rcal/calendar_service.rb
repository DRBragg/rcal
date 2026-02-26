require "json"
require "yaml"
require "google/apis/calendar_v3"
require "googleauth"
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

      def load_credentials
        client_creds = load_client_credentials
        token_data = load_google_token_data

        return nil if client_creds.nil? || token_data.nil?

        Google::Auth::UserRefreshCredentials.new(
          client_id: client_creds["client_id"],
          client_secret: client_creds["client_secret"],
          access_token: token_data["access_token"],
          refresh_token: token_data["refresh_token"],
          expires_at: token_data["expiration_time_millis"] ? Time.at(token_data["expiration_time_millis"] / 1000) : nil
        )
      end

      def load_client_credentials
        creds_file = File.join(Configuration.data_dir, "client_credentials.json")
        return nil unless File.exist?(creds_file)

        JSON.parse(File.read(creds_file))
      rescue JSON::ParserError
        nil
      end

      def load_google_token_data
        token_file = File.join(Configuration.data_dir, "google_tokens.yaml")
        return nil unless File.exist?(token_file)

        yaml_data = YAML.safe_load_file(token_file)
        return nil unless yaml_data&.key?("default")

        JSON.parse(yaml_data["default"])
      rescue JSON::ParserError, Psych::SyntaxError
        nil
      end
    end
  end
end
