module Rcal
  module Adapters
    module IcsParser
      class Base
        def parse(content)
          raise NotImplementedError, "#{self.class} must implement #parse"
        end

        def parse_file(path)
          raise NotImplementedError, "#{self.class} must implement #parse_file"
        end
      end
    end
  end
end
