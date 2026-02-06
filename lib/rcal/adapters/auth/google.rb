require "json"
require "fileutils"
require_relative "base"

module Rcal
  module Adapters
    module Auth
      class Google < Base
        def self.default_token_path
          base = ENV.fetch("XDG_DATA_HOME") { File.join(ENV.fetch("HOME"), ".local", "share") }
          File.join(base, "rcal", "tokens.json")
        end

        def initialize(token_path: self.class.default_token_path)
          @token_path = token_path
        end

        def store_credentials(credentials)
          ensure_directory_exists

          token_data = {
            "access_token" => credentials.access_token,
            "refresh_token" => credentials.refresh_token,
            "expires_at" => credentials.expires_at.to_i
          }

          File.write(@token_path, JSON.generate(token_data))
          File.chmod(0o600, @token_path)
        end

        def load_credentials
          return nil unless File.exist?(@token_path)

          JSON.parse(File.read(@token_path))
        rescue JSON::ParserError
          nil
        end

        def authenticated?
          creds = load_credentials
          return false if creds.nil?

          # Need at least a refresh token to be considered authenticated
          # (we can refresh expired access tokens)
          !creds["refresh_token"].nil? && !creds["refresh_token"].empty?
        end

        def token_expired?
          creds = load_credentials
          return true if creds.nil?

          expires_at = creds["expires_at"]
          return true if expires_at.nil?

          Time.at(expires_at) <= Time.now
        end

        def clear_credentials
          FileUtils.rm_f(@token_path)
        end

        private

        def ensure_directory_exists
          dir = File.dirname(@token_path)
          FileUtils.mkdir_p(dir) unless File.directory?(dir)
        end
      end
    end
  end
end
