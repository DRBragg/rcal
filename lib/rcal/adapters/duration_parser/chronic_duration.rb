require "chronic_duration"
require_relative "base"
require_relative "../../errors"

module Rcal
  module Adapters
    module DurationParser
      class ChronicDuration < Base
        class << self
          def parse(input)
            new.parse(input)
          end

          def parse_minutes(input)
            new.parse_minutes(input)
          end
        end

        def parse(input)
          normalized = normalize_input(input)
          validate_input!(normalized)

          result = ::ChronicDuration.parse(normalized)

          raise Rcal::ParseError, "Could not parse duration: #{input.inspect}" if result.nil?

          result
        end

        def parse_minutes(input)
          seconds = parse(input)
          seconds / 60
        end

        private

        def normalize_input(input)
          input.to_s.strip
        end

        def validate_input!(input)
          raise Rcal::ParseError, "Input cannot be empty" if input.empty?
        end
      end
    end
  end
end
