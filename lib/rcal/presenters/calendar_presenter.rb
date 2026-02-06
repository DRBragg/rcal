module Rcal
  module Presenters
    class CalendarPresenter
      def initialize(calendar)
        @calendar = calendar
      end

      def to_s
        parts = []
        parts << @calendar.name
        parts << "(#{@calendar.id})"
        parts << role_indicator
        parts << "[primary]" if @calendar.primary?

        parts.compact.join("  ")
      end

      def to_s_compact
        @calendar.name
      end

      private

      def role_indicator
        case @calendar.access_role
        when "owner"
          "[owner]"
        when "reader", "freeBusyReader"
          "[read-only]"
        end
      end
    end
  end
end
