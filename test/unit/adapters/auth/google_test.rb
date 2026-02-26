require "test_helper"
require "rcal/adapters/auth/base"
require "rcal/adapters/auth/google"

module Rcal
  module Adapters
    module Auth
      class GoogleTest < Minitest::Test
        def setup
          @temp_dir = Dir.mktmpdir
          @adapter = Google.new(data_dir: @temp_dir)
          @token_path = File.join(@temp_dir, "google_tokens.yaml")
          @client_creds_path = File.join(@temp_dir, "client_credentials.json")
        end

        def teardown
          FileUtils.remove_entry(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
        end

        # Token Storage Tests

        def test_stores_credentials_to_yaml_file
          credentials = stub_credentials(
            client_id: "test_client_id",
            access_token: "test_access_token",
            refresh_token: "test_refresh_token",
            scope: ["https://www.googleapis.com/auth/calendar.readonly"],
            expires_at: Time.now + 3600
          )

          @adapter.store_credentials(credentials)

          assert File.exist?(@token_path), "Token file should be created"

          yaml_data = YAML.safe_load_file(@token_path)
          assert yaml_data.key?("default"), "YAML should have 'default' key"

          stored = JSON.parse(yaml_data["default"])
          assert_equal "test_access_token", stored["access_token"]
          assert_equal "test_refresh_token", stored["refresh_token"]
          assert_equal "test_client_id", stored["client_id"]
          assert stored["expiration_time_millis"].is_a?(Integer)
        end

        def test_store_creates_parent_directory
          nested_dir = File.join(@temp_dir, "nested", "dir")
          adapter = Google.new(data_dir: nested_dir)

          credentials = stub_credentials(
            client_id: "test_client_id",
            access_token: "test_token",
            refresh_token: "refresh",
            scope: [],
            expires_at: Time.now + 3600
          )

          adapter.store_credentials(credentials)

          assert File.exist?(File.join(nested_dir, "google_tokens.yaml"))
        end

        def test_stored_file_has_restricted_permissions
          credentials = stub_credentials(
            client_id: "test_client_id",
            access_token: "secret_token",
            refresh_token: "secret_refresh",
            scope: [],
            expires_at: Time.now + 3600
          )

          @adapter.store_credentials(credentials)

          mode = File.stat(@token_path).mode & 0o777
          assert_equal 0o600, mode, "Token file should have restricted permissions"
        end

        def test_stored_expiration_is_in_milliseconds
          expires_at = Time.now + 3600
          credentials = stub_credentials(
            client_id: "test_client_id",
            access_token: "token",
            refresh_token: "refresh",
            scope: [],
            expires_at: expires_at
          )

          @adapter.store_credentials(credentials)

          yaml_data = YAML.safe_load_file(@token_path)
          stored = JSON.parse(yaml_data["default"])
          assert_equal expires_at.to_i * 1000, stored["expiration_time_millis"]
        end

        # Token Retrieval Tests

        def test_load_credentials_returns_nil_when_no_file
          refute File.exist?(@token_path)
          assert_nil @adapter.load_credentials
        end

        def test_load_credentials_returns_stored_data
          write_token_yaml(
            access_token: "stored_access",
            refresh_token: "stored_refresh",
            expiration_time_millis: (Time.now.to_i + 3600) * 1000
          )

          result = @adapter.load_credentials

          assert_equal "stored_access", result["access_token"]
          assert_equal "stored_refresh", result["refresh_token"]
        end

        def test_load_credentials_returns_nil_for_invalid_yaml
          File.write(@token_path, "not valid yaml {{{: :")

          assert_nil @adapter.load_credentials
        end

        def test_load_credentials_returns_nil_for_missing_default_key
          File.write(@token_path, YAML.dump({"other_user" => "{}"}))

          assert_nil @adapter.load_credentials
        end

        # Authentication State Tests

        def test_authenticated_returns_false_when_no_credentials
          refute @adapter.authenticated?
        end

        def test_authenticated_returns_true_when_credentials_and_client_creds_exist
          write_token_yaml(
            access_token: "valid_token",
            refresh_token: "refresh",
            expiration_time_millis: (Time.now.to_i + 3600) * 1000
          )
          write_client_credentials

          assert @adapter.authenticated?
        end

        def test_authenticated_returns_true_even_with_expired_token
          write_token_yaml(
            access_token: "expired_token",
            refresh_token: "refresh",
            expiration_time_millis: (Time.now.to_i - 3600) * 1000
          )
          write_client_credentials

          assert @adapter.authenticated?
        end

        def test_authenticated_returns_false_when_no_refresh_token
          write_token_yaml(
            access_token: "token_only",
            expiration_time_millis: (Time.now.to_i - 3600) * 1000
          )
          write_client_credentials

          refute @adapter.authenticated?
        end

        def test_authenticated_returns_false_when_no_client_credentials
          write_token_yaml(
            access_token: "valid_token",
            refresh_token: "refresh",
            expiration_time_millis: (Time.now.to_i + 3600) * 1000
          )
          # No client_credentials.json written

          refute @adapter.authenticated?
        end

        # Token Expiry Tests

        def test_token_expired_returns_true_when_expired
          write_token_yaml(
            access_token: "old_token",
            refresh_token: "refresh",
            expiration_time_millis: (Time.now.to_i - 60) * 1000
          )

          assert @adapter.token_expired?
        end

        def test_token_expired_returns_false_when_valid
          write_token_yaml(
            access_token: "fresh_token",
            refresh_token: "refresh",
            expiration_time_millis: (Time.now.to_i + 3600) * 1000
          )

          refute @adapter.token_expired?
        end

        def test_token_expired_returns_true_when_no_credentials
          assert @adapter.token_expired?
        end

        # Clear Credentials Tests

        def test_clear_credentials_removes_token_file
          write_token_yaml(access_token: "to_delete")

          @adapter.clear_credentials

          refute File.exist?(@token_path)
        end

        def test_clear_credentials_also_removes_legacy_token_file
          legacy_path = File.join(@temp_dir, "tokens.json")
          File.write(legacy_path, JSON.generate({"access_token" => "legacy"}))

          @adapter.clear_credentials

          refute File.exist?(legacy_path), "Legacy tokens.json should be cleaned up"
        end

        def test_clear_credentials_does_not_error_when_no_file
          refute File.exist?(@token_path)
          @adapter.clear_credentials # Should not raise
        end

        # Client Credentials Tests

        def test_load_client_credentials_returns_nil_when_no_file
          assert_nil @adapter.load_client_credentials
        end

        def test_load_client_credentials_returns_stored_data
          write_client_credentials(
            client_id: "my_client_id",
            client_secret: "my_client_secret"
          )

          result = @adapter.load_client_credentials

          assert_equal "my_client_id", result["client_id"]
          assert_equal "my_client_secret", result["client_secret"]
        end

        def test_load_client_credentials_returns_nil_for_invalid_json
          File.write(@client_creds_path, "not valid json {{{")

          assert_nil @adapter.load_client_credentials
        end

        # Path Tests

        def test_token_path_returns_yaml_path
          expected = File.join(@temp_dir, "google_tokens.yaml")
          assert_equal expected, @adapter.token_path
        end

        def test_client_credentials_path
          expected = File.join(@temp_dir, "client_credentials.json")
          assert_equal expected, @adapter.client_credentials_path
        end

        # SCOPES constant test

        def test_scopes_includes_required_google_calendar_scopes
          assert_includes Google::SCOPES, "https://www.googleapis.com/auth/calendar.readonly"
          assert_includes Google::SCOPES, "https://www.googleapis.com/auth/calendar.events"
        end

        private

        def stub_credentials(client_id:, access_token:, refresh_token:, scope:, expires_at:)
          mock = Minitest::Mock.new
          mock.expect(:client_id, client_id)
          mock.expect(:access_token, access_token)
          mock.expect(:refresh_token, refresh_token)
          mock.expect(:scope, scope)
          mock.expect(:expires_at, expires_at)
          mock
        end

        def write_token_yaml(access_token: "token", refresh_token: nil, expiration_time_millis: nil)
          token_data = {"access_token" => access_token}
          token_data["refresh_token"] = refresh_token if refresh_token
          token_data["expiration_time_millis"] = expiration_time_millis if expiration_time_millis

          yaml_data = {"default" => JSON.generate(token_data)}
          File.write(@token_path, YAML.dump(yaml_data))
        end

        def write_client_credentials(client_id: "test_client_id", client_secret: "test_client_secret")
          data = {"client_id" => client_id, "client_secret" => client_secret}
          File.write(@client_creds_path, JSON.generate(data))
        end
      end
    end
  end
end
