require_relative "errors"

module Rcal
  module RecurrenceBuilder
    VALID_FREQUENCIES = %w[daily weekly monthly yearly].freeze

    VALID_DAYS = %w[SU MO TU WE TH FR SA].freeze

    # Maps full and abbreviated day names to RFC 5545 BYDAY abbreviations.
    # Case-insensitive lookup via downcase key.
    DAY_ALIASES = {
      "sunday" => "SU", "sun" => "SU", "su" => "SU",
      "monday" => "MO", "mon" => "MO", "mo" => "MO",
      "tuesday" => "TU", "tue" => "TU", "tu" => "TU",
      "wednesday" => "WE", "wed" => "WE", "we" => "WE",
      "thursday" => "TH", "thu" => "TH", "th" => "TH",
      "friday" => "FR", "fri" => "FR", "fr" => "FR",
      "saturday" => "SA", "sat" => "SA", "sa" => "SA"
    }.freeze

    class << self
      # Builds an RFC 5545 RRULE string from structured options.
      #
      # @param freq [String] Recurrence frequency: daily, weekly, monthly, yearly (required)
      # @param days [String, nil] Comma-separated day names/abbreviations (e.g., "MO,WE,FR" or "Monday,Wed")
      # @param count [String, Integer, nil] Number of occurrences
      # @param until_date [String, nil] End date for recurrence (ISO 8601 or natural language date string)
      # @param interval [String, Integer, nil] Repeat every N periods (default: 1, omitted when 1)
      #
      # @return [Array<String>] Single-element array with the RRULE string, e.g., ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=10"]
      # @raise [Rcal::Error] If options are invalid
      def build(freq:, days: nil, count: nil, until_date: nil, interval: nil)
        validate_freq!(freq)
        validate_count_until_exclusivity!(count, until_date)

        parts = ["FREQ=#{freq.upcase}"]

        interval_val = parse_interval(interval)
        parts << "INTERVAL=#{interval_val}" if interval_val && interval_val > 1
        parts << "BYDAY=#{normalize_days(days).join(",")}" if days
        parts << "COUNT=#{parse_count(count)}" if count
        parts << "UNTIL=#{format_until(until_date)}" if until_date

        ["RRULE:#{parts.join(";")}"]
      end

      private

      def validate_freq!(freq)
        unless VALID_FREQUENCIES.include?(freq.to_s.downcase)
          raise Rcal::Error,
            "Invalid recurrence frequency: #{freq}. " \
            "Valid values: #{VALID_FREQUENCIES.join(", ")}"
        end
      end

      def validate_count_until_exclusivity!(count, until_date)
        if count && until_date
          raise Rcal::Error, "Cannot specify both --count and --until. Use one or the other."
        end
      end

      def normalize_days(days_input)
        day_list = days_input.to_s.split(",").map(&:strip)

        day_list.map do |day|
          normalized = DAY_ALIASES[day.downcase]

          if normalized.nil?
            raise Rcal::Error,
              "Invalid day: #{day}. " \
              "Valid values: #{VALID_DAYS.join(", ")} (or full names like Monday, Tue, etc.)"
          end

          normalized
        end
      end

      def parse_count(count)
        val = count.to_i

        unless val.positive?
          raise Rcal::Error, "Count must be a positive integer, got: #{count}"
        end

        val
      end

      def parse_interval(interval)
        return if interval.nil?

        val = interval.to_i

        unless val.positive?
          raise Rcal::Error, "Interval must be a positive integer, got: #{interval}"
        end

        val
      end

      def format_until(until_date)
        # Parse the date and format as YYYYMMDD for all-day style UNTIL,
        # or YYYYMMDDTHHMMSSZ for datetime UNTIL.
        # Google Calendar accepts both; we use the date-only form for simplicity.
        date = Date.parse(until_date.to_s)
        date.strftime("%Y%m%dT235959Z")
      rescue ArgumentError
        raise Rcal::Error,
          "Could not parse until date: #{until_date}. Use a date like '2024-12-31'."
      end
    end
  end
end
