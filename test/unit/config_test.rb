require "test_helper"
require "rcal/config"

module Rcal
  class ConfigurationurationTest < Minitest::Test
    def setup
      @original_env = ENV.to_h
      @temp_dir = Dir.mktmpdir
    end

    def teardown
      ENV.replace(@original_env)
      FileUtils.remove_entry(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
    end

    def test_config_dir_uses_xdg_config_home_when_set
      ENV["XDG_CONFIG_HOME"] = @temp_dir

      assert_equal File.join(@temp_dir, "rcal"), Configuration.config_dir
    end

    def test_config_dir_falls_back_to_home_config_when_xdg_not_set
      ENV.delete("XDG_CONFIG_HOME")
      ENV["HOME"] = @temp_dir

      assert_equal File.join(@temp_dir, ".config", "rcal"), Configuration.config_dir
    end

    def test_data_dir_uses_xdg_data_home_when_set
      ENV["XDG_DATA_HOME"] = @temp_dir

      assert_equal File.join(@temp_dir, "rcal"), Configuration.data_dir
    end

    def test_data_dir_falls_back_to_home_local_share_when_xdg_not_set
      ENV.delete("XDG_DATA_HOME")
      ENV["HOME"] = @temp_dir

      assert_equal File.join(@temp_dir, ".local", "share", "rcal"), Configuration.data_dir
    end

    def test_load_returns_empty_config_when_file_does_not_exist
      ENV["XDG_CONFIG_HOME"] = @temp_dir

      config = Configuration.load

      assert_equal({}, config.to_h)
    end

    def test_load_parses_yaml_config_file
      ENV["XDG_CONFIG_HOME"] = @temp_dir
      config_dir = File.join(@temp_dir, "rcal")
      FileUtils.mkdir_p(config_dir)
      File.write(File.join(config_dir, "config.yml"), <<~YAML)
        default_calendar: primary
        settings:
          start_of_day: "9am"
          end_of_day: "6pm"
      YAML

      config = Configuration.load

      assert_equal "primary", config.default_calendar
      assert_equal "9am", config.settings["start_of_day"]
      assert_equal "6pm", config.settings["end_of_day"]
    end

    def test_config_file_path
      ENV["XDG_CONFIG_HOME"] = @temp_dir

      assert_equal File.join(@temp_dir, "rcal", "config.yml"), Configuration.config_file_path
    end

    def test_responds_to_top_level_keys
      ENV["XDG_CONFIG_HOME"] = @temp_dir
      config_dir = File.join(@temp_dir, "rcal")
      FileUtils.mkdir_p(config_dir)
      File.write(File.join(config_dir, "config.yml"), <<~YAML)
        default_calendar: work@example.com
        calendars:
          - personal@gmail.com
          - work@example.com
      YAML

      config = Configuration.load

      assert_equal "work@example.com", config.default_calendar
      assert_equal ["personal@gmail.com", "work@example.com"], config.calendars
    end

    def test_returns_nil_for_missing_keys
      ENV["XDG_CONFIG_HOME"] = @temp_dir

      config = Configuration.load

      assert_nil config.default_calendar
      assert_nil config.nonexistent_key
    end

    def test_settings_returns_empty_hash_when_not_configured
      ENV["XDG_CONFIG_HOME"] = @temp_dir

      config = Configuration.load

      assert_equal({}, config.settings)
    end

    def test_calendars_returns_empty_array_when_not_configured
      ENV["XDG_CONFIG_HOME"] = @temp_dir

      config = Configuration.load

      assert_equal [], config.calendars
    end
  end
end
