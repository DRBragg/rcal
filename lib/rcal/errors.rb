module Rcal
  class Error < StandardError; end

  class ParseError < Error; end

  class InvalidPredicateError < Error; end
end
