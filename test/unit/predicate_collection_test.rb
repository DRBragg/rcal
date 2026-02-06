require "test_helper"
require "timecop"
require "rcal/predicate_collection"
require "rcal/models/event"

module Rcal
  class PredicateCollectionTest < Minitest::Test
    def setup
      @frozen_time = Time.local(2026, 1, 30, 10, 0, 0)
      Timecop.freeze(@frozen_time)
    end

    def teardown
      Timecop.return
    end

    # Filtering with must_be

    def test_filters_events_with_single_must_be_predicate
      accepted_event = Event.new(summary: "Accepted", start_time: Time.now, response_status: "accepted")
      declined_event = Event.new(summary: "Declined", start_time: Time.now, response_status: "declined")
      events = [accepted_event, declined_event]

      collection = PredicateCollection.new(must_be: [:accepted?])
      filtered = collection.filter(events)

      assert_equal [accepted_event], filtered
    end

    def test_filters_events_with_multiple_must_be_predicates
      # Event that is both accepted AND recurring
      accepted_recurring = Event.new(
        summary: "Standup",
        start_time: Time.now,
        response_status: "accepted",
        recurrence: ["RRULE:FREQ=DAILY"]
      )
      # Event that is accepted but not recurring
      accepted_once = Event.new(
        summary: "One-off",
        start_time: Time.now,
        response_status: "accepted"
      )
      events = [accepted_recurring, accepted_once]

      collection = PredicateCollection.new(must_be: [:accepted?, :recurring?])
      filtered = collection.filter(events)

      assert_equal [accepted_recurring], filtered
    end

    # Filtering with must_not_be

    def test_filters_events_with_single_must_not_be_predicate
      accepted_event = Event.new(summary: "Accepted", start_time: Time.now, response_status: "accepted")
      declined_event = Event.new(summary: "Declined", start_time: Time.now, response_status: "declined")
      events = [accepted_event, declined_event]

      collection = PredicateCollection.new(must_not_be: [:declined?])
      filtered = collection.filter(events)

      assert_equal [accepted_event], filtered
    end

    def test_filters_events_with_multiple_must_not_be_predicates
      regular_event = Event.new(summary: "Meeting", start_time: Time.now, response_status: "accepted")
      declined_event = Event.new(summary: "Declined", start_time: Time.now, response_status: "declined")
      all_day_event = Event.new(summary: "Holiday", start_time: Date.today, all_day: true, response_status: "accepted")
      events = [regular_event, declined_event, all_day_event]

      collection = PredicateCollection.new(must_not_be: [:declined?, :all_day?])
      filtered = collection.filter(events)

      assert_equal [regular_event], filtered
    end

    # Combined must_be and must_not_be

    def test_filters_with_both_must_be_and_must_not_be
      # Accepted, recurring
      accepted_recurring = Event.new(
        summary: "Standup",
        start_time: Time.now,
        response_status: "accepted",
        recurrence: ["RRULE:FREQ=DAILY"]
      )
      # Accepted, not recurring
      accepted_once = Event.new(
        summary: "One-off",
        start_time: Time.now,
        response_status: "accepted"
      )
      # Declined, recurring
      declined_recurring = Event.new(
        summary: "Declined Standup",
        start_time: Time.now,
        response_status: "declined",
        recurrence: ["RRULE:FREQ=DAILY"]
      )
      events = [accepted_recurring, accepted_once, declined_recurring]

      # Must be recurring, must not be declined
      collection = PredicateCollection.new(must_be: [:recurring?], must_not_be: [:declined?])
      filtered = collection.filter(events)

      assert_equal [accepted_recurring], filtered
    end

    # Empty predicates

    def test_returns_all_events_with_no_predicates
      event1 = Event.new(summary: "Event 1", start_time: Time.now)
      event2 = Event.new(summary: "Event 2", start_time: Time.now)
      events = [event1, event2]

      collection = PredicateCollection.new
      filtered = collection.filter(events)

      assert_equal events, filtered
    end

    def test_returns_empty_array_when_no_events_match
      declined_event = Event.new(summary: "Declined", start_time: Time.now, response_status: "declined")
      events = [declined_event]

      collection = PredicateCollection.new(must_be: [:accepted?])
      filtered = collection.filter(events)

      assert_equal [], filtered
    end

    # Matches single event

    def test_matches_returns_true_when_event_matches
      event = Event.new(summary: "Meeting", start_time: Time.now, response_status: "accepted")

      collection = PredicateCollection.new(must_be: [:accepted?])

      assert collection.matches?(event)
    end

    def test_matches_returns_false_when_event_does_not_match
      event = Event.new(summary: "Meeting", start_time: Time.now, response_status: "declined")

      collection = PredicateCollection.new(must_be: [:accepted?])

      refute collection.matches?(event)
    end

    # String predicates (for CLI input)

    def test_accepts_string_predicates
      accepted_event = Event.new(summary: "Accepted", start_time: Time.now, response_status: "accepted")
      declined_event = Event.new(summary: "Declined", start_time: Time.now, response_status: "declined")
      events = [accepted_event, declined_event]

      collection = PredicateCollection.new(must_be: ["accepted?"])
      filtered = collection.filter(events)

      assert_equal [accepted_event], filtered
    end

    def test_accepts_predicates_without_question_mark
      accepted_event = Event.new(summary: "Accepted", start_time: Time.now, response_status: "accepted")
      declined_event = Event.new(summary: "Declined", start_time: Time.now, response_status: "declined")
      events = [accepted_event, declined_event]

      collection = PredicateCollection.new(must_be: ["accepted"])
      filtered = collection.filter(events)

      assert_equal [accepted_event], filtered
    end

    # Valid predicates list

    def test_valid_predicates_returns_list_of_available_predicates
      predicates = PredicateCollection.valid_predicates

      assert_includes predicates, :accepted?
      assert_includes predicates, :declined?
      assert_includes predicates, :recurring?
      assert_includes predicates, :busy?
      assert_includes predicates, :all_day?
      assert_includes predicates, :past?
      assert_includes predicates, :future?
      assert_includes predicates, :current?
      assert_includes predicates, :one_on_one?
      assert_includes predicates, :commitment?
    end

    # Invalid predicates

    def test_raises_error_for_invalid_must_be_predicate
      assert_raises(Rcal::InvalidPredicateError) do
        PredicateCollection.new(must_be: [:invalid_predicate?])
      end
    end

    def test_raises_error_for_invalid_must_not_be_predicate
      assert_raises(Rcal::InvalidPredicateError) do
        PredicateCollection.new(must_not_be: [:not_a_real_predicate?])
      end
    end
  end
end
