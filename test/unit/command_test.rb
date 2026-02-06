require "test_helper"
require "rcal/command"

module Rcal
  class CommandTest < Minitest::Test
    class TestCommand < Rcal::Command
      def self.help
        "Test command help text"
      end

      def run(args, _name)
        @ran = true
        @args = args
      end

      attr_reader :ran, :args
    end

    def test_displays_help_when_help_arg_provided
      command = TestCommand.new
      output = capture_output { command.call(["help"], "test") }

      assert_includes output, "Test command help text"
      assert_nil command.ran
    end

    def test_displays_help_when_h_flag_provided
      command = TestCommand.new
      output = capture_output { command.call(["-h"], "test") }

      assert_includes output, "Test command help text"
      assert_nil command.ran
    end

    def test_displays_help_when_help_flag_provided
      command = TestCommand.new
      output = capture_output { command.call(["--help"], "test") }

      assert_includes output, "Test command help text"
      assert_nil command.ran
    end

    def test_runs_command_when_no_help_requested
      command = TestCommand.new
      command.call(["--title=Test"], "test")

      assert command.ran
      assert_equal ["--title=Test"], command.args
    end

    def test_help_flag_takes_precedence_over_other_args
      command = TestCommand.new
      output = capture_output { command.call(["--title=Test", "-h"], "test") }

      assert_includes output, "Test command help text"
      assert_nil command.ran
    end

    private

    def capture_output
      original_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original_stdout
    end
  end
end
