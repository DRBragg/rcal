require_relative "calendar_service"

module Rcal
  module TimezoneResolver
    # IANA timezone mappings for common Ruby Time#zone abbreviations.
    # Ruby's Time#zone returns abbreviated names (e.g., "EST") which are
    # ambiguous and not valid IANA identifiers. This maps the most common
    # US/international abbreviations to their IANA equivalents.
    ZONE_ABBREVIATIONS = {
      "EST" => "America/New_York",
      "EDT" => "America/New_York",
      "CST" => "America/Chicago",
      "CDT" => "America/Chicago",
      "MST" => "America/Denver",
      "MDT" => "America/Denver",
      "PST" => "America/Los_Angeles",
      "PDT" => "America/Los_Angeles",
      "AKST" => "America/Anchorage",
      "AKDT" => "America/Anchorage",
      "HST" => "Pacific/Honolulu",
      "UTC" => "Etc/UTC",
      "GMT" => "Etc/GMT"
    }.freeze

    class << self
      # Resolves the timezone to use for an event, using a layered approach:
      #   1. Explicit timezone (from --timezone flag)
      #   2. Calendar's default timezone (from Google Calendar API)
      #   3. System local timezone (last resort fallback)
      #
      # Returns an IANA timezone string (e.g., "America/New_York").
      def resolve(explicit: nil, calendar_id: nil)
        explicit || calendar_timezone(calendar_id) || system_timezone
      end

      # Fetches the calendar's default timezone from the API.
      # Returns nil on any failure (network error, missing calendar, etc.)
      def calendar_timezone(calendar_id)
        return if calendar_id.nil?

        CalendarService.get_calendar(calendar_id: calendar_id)&.timezone
      rescue => _e
        nil
      end

      # Returns the system's local timezone as an IANA identifier.
      # Tries ENV["TZ"] first, then falls back to mapping Ruby's
      # Time#zone abbreviation.
      def system_timezone
        env_tz = ENV["TZ"]
        return env_tz if env_tz && !env_tz.empty? && env_tz.include?("/")

        ZONE_ABBREVIATIONS[Time.now.zone] || "Etc/UTC"
      end
    end
  end
end
