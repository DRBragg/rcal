require "rcal"

module Rcal
  module Commands
    class Help < Rcal::Command
      def run(args, _name)
        puts CLI::UI.fmt("{{bold:Available commands}}")
        puts ""

        Rcal::Commands::Registry.resolved_commands.each do |name, klass|
          next if name == "help"
          puts CLI::UI.fmt("{{command:#{Rcal::TOOL_NAME} #{name}}}")
          if (help = klass.help)
            puts CLI::UI.fmt(help)
          end
          puts ""
        end
      end
    end
  end
end
