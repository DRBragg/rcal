require "rcal"

module Rcal
  module EntryPoint
    def self.call(args)
      cmd, command_name, args = Rcal::Resolver.call(args)
      Rcal::Executor.call(cmd, command_name, args)
    end
  end
end
