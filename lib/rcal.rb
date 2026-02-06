require_relative "rcal/version"

require "cli/ui"
require "cli/kit"

CLI::UI::StdoutRouter.enable

module Rcal
  TOOL_NAME = "rcal"
  ROOT = File.expand_path("../..", __FILE__)
  LOG_FILE = "/tmp/rcal.log"

  autoload(:EntryPoint, "rcal/entry_point")
  autoload(:Commands, "rcal/commands")
  autoload(:Configuration, "rcal/config")
  autoload(:Command, "rcal/command")

  CLIConfig = CLI::Kit::Config.new(tool_name: TOOL_NAME)

  Executor = CLI::Kit::Executor.new(log_file: LOG_FILE)
  Resolver = CLI::Kit::Resolver.new(
    tool_name: TOOL_NAME,
    command_registry: Rcal::Commands::Registry
  )

  ErrorHandler = CLI::Kit::ErrorHandler.new(log_file: LOG_FILE)
end
