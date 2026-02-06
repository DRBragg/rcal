module Rcal
  module Presenters
    class EventPresenter
      def initialize(event, show_location: false, show_duration: false)
        @event = event
        @show_location = show_location
        @show_duration = show_duration
      end

      def to_s
        parts = []
        parts << time_range
        parts << summary_with_attributes
        parts << location_part if @show_location && @event.location
        parts << duration_part if @show_duration

        parts.compact.join("  ")
      end

      def to_s_with_date
        "#{formatted_date}  #{self}"
      end

      def to_s_compact
        "#{compact_time} #{@event.summary}"
      end

      def declined?
        @event.declined?
      end

      private

      def time_range
        if @event.all_day?
          "All day"
        else
          "#{format_time(@event.start_time)} - #{format_time(@event.end_time)}"
        end
      end

      def compact_time
        if @event.all_day?
          "All day"
        else
          format_time(@event.start_time)
        end
      end

      def format_time(time)
        time.strftime("%H:%M")
      end

      def formatted_date
        @event.start_time.strftime("%a %b %d")
      end

      def summary_with_attributes
        attrs = attributes_list
        if attrs.empty?
          @event.summary
        else
          "#{@event.summary} (#{attrs.join(", ")})"
        end
      end

      def attributes_list
        attrs = []
        attrs << "recurring" if @event.recurring?
        attrs << "1:1" if @event.one_on_one?
        attrs << "awaiting" if @event.awaiting?
        attrs << "tentative" if @event.tentative?
        attrs << "free" if !@event.busy?
        attrs
      end

      def location_part
        @event.location
      end

      def duration_part
        seconds = @event.duration
        return nil if seconds <= 0

        hours = seconds / 3600
        minutes = (seconds % 3600) / 60

        if hours > 0 && minutes > 0
          "#{hours}h #{minutes}m"
        elsif hours > 0
          "#{hours}h"
        else
          "#{minutes}m"
        end
      end
    end
  end
end
