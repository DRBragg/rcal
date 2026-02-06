require_relative "errors"

module Rcal
  class PredicateCollection
    VALID_PREDICATES = %i[
      accepted?
      declined?
      awaiting?
      tentative?
      all_day?
      past?
      current?
      future?
      busy?
      recurring?
      one_on_one?
      commitment?
    ].freeze

    def self.valid_predicates
      VALID_PREDICATES
    end

    def initialize(must_be: [], must_not_be: [])
      @must_be = normalize_predicates(must_be)
      @must_not_be = normalize_predicates(must_not_be)

      validate_predicates!
    end

    def filter(events)
      events.select { |event| matches?(event) }
    end

    def matches?(event)
      must_be_satisfied?(event) && must_not_be_satisfied?(event)
    end

    private

    def normalize_predicates(predicates)
      predicates.map do |predicate|
        normalized = predicate.to_s
        normalized += "?" unless normalized.end_with?("?")
        normalized.to_sym
      end
    end

    def validate_predicates!
      invalid = (@must_be + @must_not_be) - VALID_PREDICATES

      if invalid.any?
        raise InvalidPredicateError, "Invalid predicates: #{invalid.join(", ")}"
      end
    end

    def must_be_satisfied?(event)
      @must_be.all? { |predicate| event.public_send(predicate) }
    end

    def must_not_be_satisfied?(event)
      @must_not_be.none? { |predicate| event.public_send(predicate) }
    end
  end
end
