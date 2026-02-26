require "json"
require "yaml"
require "fileutils"
require_relative "base"

module Rcal
  module Adapters
    module Auth
      class Google < Base
        SCOPES = [
          "https://www.googleapis.com/auth/calendar.readonly",
          "https://www.googleapis.com/auth/calendar.events"
        ].freeze

        TOKEN_FILENAME = "google_tokens.yaml"
        CLIENT_CREDENTIALS_FILENAME = "client_credentials.json"
        LEGACY_TOKEN_FILENAME = "tokens.json"

        def initialize(data_dir:)
          @data_dir = data_dir
        end

        def store_credentials(credentials)
          ensure_directory_exists

          token_data = {
            "client_id" => credentials.client_id,
            "access_token" => credentials.access_token,
            "refresh_token" => credentials.refresh_token,
            "scope" => Array(credentials.scope),
            "expiration_time_millis" => (credentials.expires_at.to_i * 1000)
          }

          yaml_data = {"default" => JSON.generate(token_data)}
          File.write(token_path, YAML.dump(yaml_data))
          File.chmod(0o600, token_path)
        end

        def load_credentials
          return nil unless File.exist?(token_path)

          yaml_data = YAML.safe_load_file(token_path)
          return nil unless yaml_data&.key?("default")

          JSON.parse(yaml_data["default"])
        rescue JSON::ParserError, Psych::SyntaxError
          nil
        end

        def authenticated?
          creds = load_credentials
          return false if creds.nil?

          client_creds = load_client_credentials
          return false if client_creds.nil?

          # Need at least a refresh token to be considered authenticated
          # (we can refresh expired access tokens)
          !creds["refresh_token"].nil? && !creds["refresh_token"].empty?
        end

        def token_expired?
          creds = load_credentials
          return true if creds.nil?

          expiration = creds["expiration_time_millis"]
          return true if expiration.nil?

          Time.at(expiration / 1000) <= Time.now
        end

        def clear_credentials
          FileUtils.rm_f(token_path)
          # Clean up legacy token file if it exists from a previous version
          FileUtils.rm_f(legacy_token_path)
        end

        def load_client_credentials
          creds_file = client_credentials_path
          return nil unless File.exist?(creds_file)

          JSON.parse(File.read(creds_file))
        rescue JSON::ParserError
          nil
        end

        def token_path
          File.join(@data_dir, TOKEN_FILENAME)
        end

        def client_credentials_path
          File.join(@data_dir, CLIENT_CREDENTIALS_FILENAME)
        end

        private

        def legacy_token_path
          File.join(@data_dir, LEGACY_TOKEN_FILENAME)
        end

        def ensure_directory_exists
          FileUtils.mkdir_p(@data_dir) unless File.directory?(@data_dir)
        end
      end
    end
  end
end
