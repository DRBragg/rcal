module Rcal
  module ColorMap
    COLORS = {
      "lavender" => "1",
      "sage" => "2",
      "grape" => "3",
      "flamingo" => "4",
      "banana" => "5",
      "tangerine" => "6",
      "peacock" => "7",
      "graphite" => "8",
      "blueberry" => "9",
      "basil" => "10",
      "tomato" => "11"
    }.freeze

    IDS = COLORS.values.freeze

    class << self
      # Resolves a color name or numeric ID to a Google Calendar color ID string.
      # Accepts names ("tomato"), IDs ("11"), or IDs as integers (11).
      # Raises Rcal::Error for invalid input.
      def resolve(input)
        normalized = input.to_s.strip.downcase

        # Try as a name first
        return COLORS[normalized] if COLORS.key?(normalized)

        # Try as a numeric ID
        return normalized if IDS.include?(normalized)

        raise Rcal::Error, "Unknown color: #{input}. Run 'rcal colors' to see available colors."
      end

      def all
        COLORS
      end
    end
  end
end
