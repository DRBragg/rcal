module Rcal
  module Adapters
    module DateParser
      class Base
        def parse(input)
          raise NotImplementedError, "#{self.class} must implement #parse"
        end
      end
    end
  end
end
