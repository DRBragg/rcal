require_relative "../presenters/event_presenter"

module Rcal
  module Formatters
    class Agenda
      def initialize(events, date_range: nil, hide_declined: false, show_empty_days: true, compact: false, show_ids: false)
        @events = events
        @date_range = date_range
        @hide_declined = hide_declined
        @show_empty_days = show_empty_days
        @compact = compact
        @show_ids = show_ids
      end

      def format
        filtered_events = filter_events(@events)

        return "No events found." if filtered_events.empty? && @date_range.nil?

        days = group_by_day(filtered_events)

        if @date_range && @show_empty_days
          days = fill_empty_days(days)
        end

        format_days(days)
      end

      private

      def filter_events(events)
        return events unless @hide_declined

        events.reject(&:declined?)
      end

      def group_by_day(events)
        events.group_by { |e| e.start_time.to_date }
      end

      def fill_empty_days(days)
        return days if @date_range.nil?

        @date_range.each do |date|
          days[date] ||= []
        end

        days
      end

      def format_days(days)
        return "No events found." if days.empty?

        lines = []

        days.keys.sort.each do |date|
          events = days[date]
          lines << format_day_header(date)
          lines << format_day_events(events)
          lines << "" # Blank line between days
        end

        lines.join("\n").strip
      end

      def format_day_header(date)
        label = day_label(date)
        formatted_date = date.strftime("%a %b %d")

        if label
          "#{formatted_date} (#{label})"
        else
          formatted_date
        end
      end

      def day_label(date)
        today = Date.today

        case date
        when today
          "Today"
        when today + 1
          "Tomorrow"
        when today - 1
          "Yesterday"
        end
      end

      def format_day_events(events)
        return "  No events" if events.empty?

        sorted = sort_events(events)
        sorted.map { |e| format_event(e) }.join("\n")
      end

      def sort_events(events)
        # All-day events first, then by start time
        events.sort_by do |e|
          [
            e.all_day? ? 0 : 1,
            e.start_time
          ]
        end
      end

      def format_event(event)
        presenter = Rcal::Presenters::EventPresenter.new(event)

        line = @compact ? "  #{presenter.to_s_compact}" : "  #{presenter}"
        line += " [declined]" if event.declined?
        line += "\n    ID: #{event.id}" if @show_ids

        line
      end
    end
  end
end
