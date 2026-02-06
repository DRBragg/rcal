require_relative "adapters/ics_parser/icalendar"

module Rcal
  class IcsParser
    class << self
      def parse(content)
        adapter.parse(content)
      end

      def parse_file(path)
        adapter.parse_file(path)
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
        Adapters::IcsParser::Icalendar.new
      end
    end
  end
end
