require "test_helper"
require "rcal/color_map"
require "rcal/errors"

module Rcal
  class ColorMapTest < Minitest::Test
    # Resolution by name

    def test_resolves_color_by_name
      assert_equal "11", ColorMap.resolve("tomato")
    end

    def test_resolves_all_color_names
      expected = {
        "lavender" => "1", "sage" => "2", "grape" => "3",
        "flamingo" => "4", "banana" => "5", "tangerine" => "6",
        "peacock" => "7", "graphite" => "8", "blueberry" => "9",
        "basil" => "10", "tomato" => "11"
      }

      expected.each do |name, id|
        assert_equal id, ColorMap.resolve(name), "Expected #{name} to resolve to #{id}"
      end
    end

    def test_resolves_case_insensitively
      assert_equal "11", ColorMap.resolve("Tomato")
      assert_equal "11", ColorMap.resolve("TOMATO")
      assert_equal "7", ColorMap.resolve("Peacock")
    end

    def test_resolves_with_surrounding_whitespace
      assert_equal "11", ColorMap.resolve("  tomato  ")
    end

    # Resolution by ID

    def test_resolves_by_numeric_id_string
      assert_equal "1", ColorMap.resolve("1")
      assert_equal "11", ColorMap.resolve("11")
    end

    def test_resolves_by_integer_id
      assert_equal "1", ColorMap.resolve(1)
      assert_equal "11", ColorMap.resolve(11)
    end

    # Invalid input

    def test_raises_for_unknown_color_name
      error = assert_raises(Rcal::Error) do
        ColorMap.resolve("magenta")
      end

      assert_match(/unknown color/i, error.message)
      assert_includes error.message, "magenta"
    end

    def test_raises_for_out_of_range_id
      error = assert_raises(Rcal::Error) do
        ColorMap.resolve("12")
      end

      assert_match(/unknown color/i, error.message)
    end

    def test_raises_for_zero_id
      assert_raises(Rcal::Error) do
        ColorMap.resolve("0")
      end
    end

    def test_raises_for_negative_id
      assert_raises(Rcal::Error) do
        ColorMap.resolve("-1")
      end
    end

    # Listing

    def test_all_returns_complete_mapping
      all = ColorMap.all

      assert_equal 11, all.length
      assert_equal "1", all["lavender"]
      assert_equal "11", all["tomato"]
    end

    def test_all_returns_frozen_hash
      assert ColorMap.all.frozen?
    end
  end
end
