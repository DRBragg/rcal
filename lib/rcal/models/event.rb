require "time"

module Rcal
  class Event
    attr_reader :id, :summary, :start_time, :end_time, :description,
      :location, :calendar_id, :transparency, :recurrence,
      :recurring_event_id, :response_status, :attendees, :timezone,
      :color_id

    def initialize(
      summary:,
      start_time:,
      id: nil,
      end_time: nil,
      description: nil,
      location: nil,
      calendar_id: nil,
      all_day: false,
      transparency: nil,
      recurrence: nil,
      recurring_event_id: nil,
      response_status: nil,
      attendees: nil,
      timezone: nil,
      color_id: nil
    )
      @id = id
      @summary = summary
      @start_time = start_time
      @end_time = end_time || start_time
      @description = description
      @location = location
      @calendar_id = calendar_id
      @all_day = all_day
      @transparency = transparency
      @recurrence = recurrence
      @recurring_event_id = recurring_event_id
      @response_status = response_status
      @attendees = normalize_attendees(attendees)
      @timezone = timezone
      @color_id = color_id
    end

    def all_day?
      !!@all_day
    end

    def duration
      return 0 if @end_time == @start_time

      @end_time.to_i - @start_time.to_i
    end

    def accepted?
      @response_status == "accepted"
    end

    def declined?
      @response_status == "declined"
    end

    def awaiting?
      @response_status == "needsAction"
    end

    def tentative?
      @response_status == "tentative"
    end

    def past?
      @end_time < Time.now
    end

    def future?
      @start_time > Time.now
    end

    def current?
      now = Time.now
      @start_time <= now && @end_time > now
    end

    def busy?
      @transparency != "transparent"
    end

    def start_time_in_timezone
      convert_to_timezone(@start_time)
    end

    def end_time_in_timezone
      convert_to_timezone(@end_time)
    end

    def recurring?
      !@recurrence.nil? && !@recurrence.empty? || !@recurring_event_id.nil?
    end

    def one_on_one?
      return false if @attendees.nil? || @attendees.empty?
      return false unless @attendees.any? { |a| a[:self] }

      human_attendees.length == 2
    end

    def commitment?
      return false if declined?
      return false if @attendees.nil? || @attendees.empty?

      human_attendees.length >= 2
    end

    private

    def normalize_attendees(attendees)
      return nil if attendees.nil?

      attendees.map do |a|
        a.is_a?(Hash) ? a : a.to_h
      end
    end

    def human_attendees
      return [] if @attendees.nil?

      @attendees.reject { |a| a[:resource] }
    end

    def convert_to_timezone(time)
      return time if @timezone.nil?

      # Use Ruby's TZInfo-style timezone conversion if available
      # For now, use ENV-based approach for simplicity
      original_tz = ENV["TZ"]
      begin
        ENV["TZ"] = @timezone
        time.localtime
      ensure
        ENV["TZ"] = original_tz
      end
    end
  end
end
