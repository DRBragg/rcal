require "yaml"
require "fileutils"

module Rcal
  class Configuration
    class << self
      def load
        new(load_yaml)
      end

      def config_dir
        base = ENV.fetch("XDG_CONFIG_HOME") { File.join(ENV.fetch("HOME"), ".config") }
        File.join(base, "rcal")
      end

      def data_dir
        base = ENV.fetch("XDG_DATA_HOME") { File.join(ENV.fetch("HOME"), ".local", "share") }
        File.join(base, "rcal")
      end

      def config_file_path
        File.join(config_dir, "config.yml")
      end

      private

      def load_yaml
        return {} unless File.exist?(config_file_path)

        YAML.safe_load_file(config_file_path, permitted_classes: [], permitted_symbols: [], aliases: false) || {}
      end
    end

    def initialize(data = {})
      @data = data
    end

    def to_h
      @data.dup
    end

    def default_calendar
      @data["default_calendar"]
    end

    def calendars
      @data.fetch("calendars", [])
    end

    def settings
      @data.fetch("settings", {})
    end

    def [](key)
      @data[key.to_s]
    end

    def method_missing(name, *args)
      return super if name.end_with?("=") || !args.empty?

      @data[name.to_s]
    end

    def respond_to_missing?(name, include_private = false)
      !name.end_with?("=") || super
    end
  end
end
