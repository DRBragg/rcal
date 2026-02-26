begin
  addpath = lambda do |p|
    path = File.expand_path("../../#{p}", __FILE__)
    $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
  end
  addpath.call("lib")
end

require "cli/kit"

require "fileutils"
require "tmpdir"
require "tempfile"

require "rubygems"
require "bundler/setup"

CLI::UI::StdoutRouter.enable

require "minitest/autorun"
require "mocha/minitest"

module AuthTestHelper
  # Write the token and client credential files needed for
  # Auth.authenticated? to return true with the new YAML-based storage.
  def write_auth_files(temp_dir, access_token: "test_token", refresh_token: "test_refresh")
    require "yaml"
    require "json"

    token_data = {
      "client_id" => "test.apps.googleusercontent.com",
      "access_token" => access_token,
      "refresh_token" => refresh_token,
      "scope" => ["https://www.googleapis.com/auth/calendar.readonly"],
      "expiration_time_millis" => (Time.now.to_i + 3600) * 1000
    }

    yaml_data = {"default" => JSON.generate(token_data)}
    File.write(File.join(temp_dir, "google_tokens.yaml"), YAML.dump(yaml_data))

    client_creds = {"client_id" => "test.apps.googleusercontent.com", "client_secret" => "test_secret"}
    File.write(File.join(temp_dir, "client_credentials.json"), JSON.generate(client_creds))
  end
end
