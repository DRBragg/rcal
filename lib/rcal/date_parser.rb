require_relative "adapters/date_parser/chronic"

module Rcal
  class DateParser
    class << self
      def parse(input)
        adapter.parse(input)
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
        Adapters::DateParser::Chronic.new
      end
    end
  end
end
