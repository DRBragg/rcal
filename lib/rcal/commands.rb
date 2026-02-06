require "rcal"

module Rcal
  module Commands
    Registry = CLI::Kit::CommandRegistry.new(default: "help")

    def self.register(const, cmd, path)
      autoload(const, path)
      Registry.add(-> { const_get(const) }, cmd)
    end

    register :Add, "add", "rcal/commands/add"
    register :Agenda, "agenda", "rcal/commands/agenda"
    register :Edit, "edit", "rcal/commands/edit"
    register :Help, "help", "rcal/commands/help"
    register :Import, "import", "rcal/commands/import"
    register :Init, "init", "rcal/commands/init"
    register :List, "list", "rcal/commands/list"
    register :Quick, "quick", "rcal/commands/quick"
  end
end
