require_relative "adapters/duration_parser/chronic_duration"

module Rcal
  class DurationParser
    class << self
      def parse(input)
        adapter.parse(input)
      end

      def parse_minutes(input)
        adapter.parse_minutes(input)
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
        Adapters::DurationParser::ChronicDuration.new
      end
    end
  end
end
