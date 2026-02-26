require "rcal"
require_relative "../color_map"

module Rcal
  module Commands
    class Colors < Rcal::Command
      def self.help
        <<~HELP
          List available event colors.

          Usage: rcal colors

          Shows the color names and IDs that can be used with the --color option
          on the 'add' and 'edit' commands.

          Examples:
            rcal colors
            rcal add --title="Meeting" --when="tomorrow 3pm" --color=tomato
            rcal edit abc123 --color=peacock
        HELP
      end

      def run(_args, _name)
        puts "Available event colors:\n\n"

        ColorMap.all.each do |name, id|
          puts "  #{id.rjust(2)}  #{name}"
        end

        puts "\nUsage: rcal add --color=NAME or rcal add --color=ID"
      end
    end
  end
end
