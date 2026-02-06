require "chronic"
require "date"
require_relative "base"
require_relative "../../errors"

module Rcal
  module Adapters
    module DateParser
      class Chronic < Base
        # Custom relative date pattern: +N, +Nd, +Nw
        RELATIVE_PATTERN = /\A\+(\d+)(d|w)?\z/i

        class << self
          def parse(input)
            new.parse(input)
          end
        end

        def parse(input)
          normalized = normalize_input(input)
          validate_input!(normalized)

          result = parse_relative(normalized) ||
            parse_with_chronic(normalized)

          raise Rcal::ParseError, "Could not parse: #{input.inspect}" if result.nil?

          normalize_result(result, has_time_component?(normalized))
        end

        private

        def normalize_input(input)
          input.to_s.strip
        end

        def validate_input!(input)
          raise Rcal::ParseError, "Input cannot be empty" if input.empty?
        end

        def parse_relative(input)
          match = input.match(RELATIVE_PATTERN)
          return nil unless match

          count = match[1].to_i
          unit = match[2]&.downcase

          case unit
          when "w"
            Date.today + (count * 7)
          else
            Date.today + count
          end
        end

        def parse_with_chronic(input)
          ::Chronic.parse(input)
        end

        def has_time_component?(input)
          # Check if input contains time-related patterns
          time_patterns = [
            /\d{1,2}:\d{2}/,           # 14:30, 2:30
            /\d{1,2}\s*(am|pm)/i,      # 3pm, 3 pm
            /at\s+\d/i,                # at 3, at 14
            /noon/i,
            /midnight/i
          ]

          time_patterns.any? { |pattern| input.match?(pattern) }
        end

        def normalize_result(result, preserve_time)
          case result
          when Time
            preserve_time ? result : result.to_date
          when Date
            result
          else
            result.to_date
          end
        end
      end
    end
  end
end
