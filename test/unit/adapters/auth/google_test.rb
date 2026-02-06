require "test_helper"
require "rcal/adapters/auth/base"
require "rcal/adapters/auth/google"

module Rcal
  module Adapters
    module Auth
      class GoogleTest < Minitest::Test
        def setup
          @temp_dir = Dir.mktmpdir
          @token_path = File.join(@temp_dir, "tokens.json")
          @adapter = Google.new(token_path: @token_path)
        end

        def teardown
          FileUtils.remove_entry(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
        end

        # Token Storage Tests

        def test_stores_credentials_to_file
          credentials = stub_credentials(
            access_token: "test_access_token",
            refresh_token: "test_refresh_token",
            expires_at: Time.now + 3600
          )

          @adapter.store_credentials(credentials)

          assert File.exist?(@token_path), "Token file should be created"

          stored = JSON.parse(File.read(@token_path))
          assert_equal "test_access_token", stored["access_token"]
          assert_equal "test_refresh_token", stored["refresh_token"]
        end

        def test_store_creates_parent_directory
          nested_path = File.join(@temp_dir, "nested", "dir", "tokens.json")
          adapter = Google.new(token_path: nested_path)

          credentials = stub_credentials(
            access_token: "test_token",
            refresh_token: "refresh",
            expires_at: Time.now + 3600
          )

          adapter.store_credentials(credentials)

          assert File.exist?(nested_path)
        end

        def test_stored_file_has_restricted_permissions
          credentials = stub_credentials(
            access_token: "secret_token",
            refresh_token: "secret_refresh",
            expires_at: Time.now + 3600
          )

          @adapter.store_credentials(credentials)

          # File should only be readable/writable by owner (0600)
          mode = File.stat(@token_path).mode & 0o777
          assert_equal 0o600, mode, "Token file should have restricted permissions"
        end

        # Token Retrieval Tests

        def test_load_credentials_returns_nil_when_no_file
          refute File.exist?(@token_path)
          assert_nil @adapter.load_credentials
        end

        def test_load_credentials_returns_stored_data
          token_data = {
            "access_token" => "stored_access",
            "refresh_token" => "stored_refresh",
            "expires_at" => (Time.now + 3600).to_i
          }
          File.write(@token_path, JSON.generate(token_data))

          result = @adapter.load_credentials

          assert_equal "stored_access", result["access_token"]
          assert_equal "stored_refresh", result["refresh_token"]
        end

        def test_load_credentials_returns_nil_for_invalid_json
          File.write(@token_path, "not valid json {{{")

          assert_nil @adapter.load_credentials
        end

        # Authentication State Tests

        def test_authenticated_returns_false_when_no_credentials
          refute @adapter.authenticated?
        end

        def test_authenticated_returns_true_when_credentials_exist
          token_data = {
            "access_token" => "valid_token",
            "refresh_token" => "refresh",
            "expires_at" => (Time.now + 3600).to_i
          }
          File.write(@token_path, JSON.generate(token_data))

          assert @adapter.authenticated?
        end

        def test_authenticated_returns_true_even_with_expired_token
          # We can refresh expired tokens, so authenticated? should still be true
          token_data = {
            "access_token" => "expired_token",
            "refresh_token" => "refresh",
            "expires_at" => (Time.now - 3600).to_i
          }
          File.write(@token_path, JSON.generate(token_data))

          assert @adapter.authenticated?
        end

        def test_authenticated_returns_false_when_no_refresh_token
          token_data = {
            "access_token" => "token_only",
            "expires_at" => (Time.now - 3600).to_i
          }
          File.write(@token_path, JSON.generate(token_data))

          refute @adapter.authenticated?
        end

        # Token Expiry Tests

        def test_token_expired_returns_true_when_expired
          token_data = {
            "access_token" => "old_token",
            "refresh_token" => "refresh",
            "expires_at" => (Time.now - 60).to_i
          }
          File.write(@token_path, JSON.generate(token_data))

          assert @adapter.token_expired?
        end

        def test_token_expired_returns_false_when_valid
          token_data = {
            "access_token" => "fresh_token",
            "refresh_token" => "refresh",
            "expires_at" => (Time.now + 3600).to_i
          }
          File.write(@token_path, JSON.generate(token_data))

          refute @adapter.token_expired?
        end

        def test_token_expired_returns_true_when_no_credentials
          assert @adapter.token_expired?
        end

        # Clear Credentials Tests

        def test_clear_credentials_removes_token_file
          token_data = {"access_token" => "to_delete"}
          File.write(@token_path, JSON.generate(token_data))

          @adapter.clear_credentials

          refute File.exist?(@token_path)
        end

        def test_clear_credentials_does_not_error_when_no_file
          refute File.exist?(@token_path)
          @adapter.clear_credentials # Should not raise
        end

        # Default Path Tests

        def test_default_token_path_uses_xdg_data_home
          ENV["XDG_DATA_HOME"] = @temp_dir

          path = Google.default_token_path

          assert_equal File.join(@temp_dir, "rcal", "tokens.json"), path
        ensure
          ENV.delete("XDG_DATA_HOME")
        end

        def test_default_token_path_falls_back_to_home
          ENV.delete("XDG_DATA_HOME")
          home = ENV.fetch("HOME")

          path = Google.default_token_path

          assert_equal File.join(home, ".local", "share", "rcal", "tokens.json"), path
        end

        private

        def stub_credentials(access_token:, refresh_token:, expires_at:)
          mock = Minitest::Mock.new
          mock.expect(:access_token, access_token)
          mock.expect(:refresh_token, refresh_token)
          mock.expect(:expires_at, expires_at)
          mock
        end
      end
    end
  end
end
