require "cli/kit"

module Rcal
  class Command < CLI::Kit::BaseCommand
    def call(args, command_name)
      if help_requested?(args)
        display_help
        return
      end

      run(args, command_name)
    end

    # Subclasses implement this instead of call
    def run(args, command_name)
      raise NotImplementedError, "#{self.class} must implement #run"
    end

    private

    def help_requested?(args)
      args.any? { |arg| arg == "help" || arg == "-h" || arg == "--help" }
    end

    def display_help
      if self.class.respond_to?(:help) && self.class.help
        puts self.class.help
      else
        puts "No help available for this command."
      end
    end
  end
end
