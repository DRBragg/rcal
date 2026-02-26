require "test_helper"
require "rcal/commands/colors"

module Rcal
  module Commands
    class ColorsTest < Minitest::Test
      def setup
        @original_stdout = $stdout
        @output = StringIO.new
        $stdout = @output
      end

      def teardown
        $stdout = @original_stdout
      end

      def captured_output
        @output.string
      end

      def test_lists_all_eleven_colors
        cmd = Colors.new
        cmd.call([], "colors")

        ColorMap::COLORS.each do |name, id|
          assert_includes captured_output, name, "Expected output to include color name '#{name}'"
          assert_includes captured_output, id, "Expected output to include color ID '#{id}'"
        end
      end

      def test_shows_usage_hint
        cmd = Colors.new
        cmd.call([], "colors")

        assert_match(/--color/i, captured_output)
      end

      def test_has_help_text
        help = Colors.help.to_s
        assert_match(/colors/i, help)
        assert_match(/--color/i, help)
      end
    end
  end
end
