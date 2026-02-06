module Rcal
  module Adapters
    module DurationParser
      class Base
        def parse(input)
          raise NotImplementedError, "#{self.class} must implement #parse"
        end

        def parse_minutes(input)
          raise NotImplementedError, "#{self.class} must implement #parse_minutes"
        end
      end
    end
  end
end
