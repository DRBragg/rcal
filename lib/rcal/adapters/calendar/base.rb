module Rcal
  module Adapters
    module Calendar
      class Base
        def list_calendars
          raise NotImplementedError, "#{self.class} must implement #list_calendars"
        end

        def list_events(calendar_id:, time_min:, time_max:)
          raise NotImplementedError, "#{self.class} must implement #list_events"
        end

        def get_calendar(calendar_id:)
          raise NotImplementedError, "#{self.class} must implement #get_calendar"
        end

        def get_event(calendar_id:, event_id:)
          raise NotImplementedError, "#{self.class} must implement #get_event"
        end

        def create_event(calendar_id:, event:)
          raise NotImplementedError, "#{self.class} must implement #create_event"
        end

        def update_event(calendar_id:, event_id:, event:)
          raise NotImplementedError, "#{self.class} must implement #update_event"
        end

        def delete_event(calendar_id:, event_id:)
          raise NotImplementedError, "#{self.class} must implement #delete_event"
        end

        def quick_add(calendar_id:, text:)
          raise NotImplementedError, "#{self.class} must implement #quick_add"
        end
      end
    end
  end
end
