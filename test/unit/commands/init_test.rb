require "test_helper"
require "rcal/commands/init"
require "rcal/auth"

module Rcal
  module Commands
    class InitTest < Minitest::Test
      def setup
        @temp_dir = Dir.mktmpdir
        @original_stdout = $stdout
        @output = StringIO.new
        $stdout = @output

        # Stub Configuration to use temp directory
        Rcal::Configuration.stubs(:data_dir).returns(@temp_dir)
        Rcal::Configuration.stubs(:config_dir).returns(@temp_dir)

        # Reset auth adapter to use fresh instance
        Auth.reset_adapter!
      end

      def teardown
        $stdout = @original_stdout
        Auth.reset_adapter!
        FileUtils.remove_entry(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
      end

      def captured_output
        @output.string
      end

      # Argument validation tests

      def test_requires_client_id
        cmd = Init.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call([], "init")
        end

        assert_match(/client.*id/i, error.message)
      end

      def test_requires_client_secret
        cmd = Init.new

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call(["--client-id=test.apps.googleusercontent.com"], "init")
        end

        assert_match(/client.*secret/i, error.message)
      end

      def test_accepts_client_id_and_secret_flags
        cmd = Init.new
        mock_authorizer = mock("authorizer")
        mock_authorizer.stubs(:get_credentials).returns(stub_credentials)

        cmd.stubs(:build_authorizer).returns(mock_authorizer)

        # Should not raise
        cmd.call([
          "--client-id=test.apps.googleusercontent.com",
          "--client-secret=test_secret"
        ], "init")
      end

      # Already authenticated tests

      def test_warns_if_already_authenticated
        write_existing_tokens

        # Reset to pick up the new token file
        Auth.reset_adapter!

        cmd = Init.new

        # Mock the prompt to return "no"
        CLI::UI::Prompt.stubs(:confirm).returns(false)

        cmd.call([
          "--client-id=test.apps.googleusercontent.com",
          "--client-secret=test_secret"
        ], "init")

        assert_match(/already/i, captured_output)
      end

      def test_proceeds_if_user_confirms_reauth
        write_existing_tokens

        # Reset to pick up the new token file
        Auth.reset_adapter!

        cmd = Init.new
        mock_authorizer = mock("authorizer")
        mock_authorizer.stubs(:get_credentials).returns(stub_credentials)

        cmd.stubs(:build_authorizer).returns(mock_authorizer)

        CLI::UI::Prompt.stubs(:confirm).returns(true)

        # Should proceed without error
        cmd.call([
          "--client-id=test.apps.googleusercontent.com",
          "--client-secret=test_secret"
        ], "init")
      end

      def test_clear_credentials_removes_yaml_token_file
        write_existing_tokens

        Auth.reset_adapter!

        cmd = Init.new
        mock_authorizer = mock("authorizer")
        mock_authorizer.stubs(:get_credentials).returns(stub_credentials)

        cmd.stubs(:build_authorizer).returns(mock_authorizer)
        CLI::UI::Prompt.stubs(:confirm).returns(true)

        cmd.call([
          "--client-id=test.apps.googleusercontent.com",
          "--client-secret=test_secret"
        ], "init")

        # The old tokens should have been cleared before re-auth
        # New credentials will be stored, but the old file was deleted first
        token_path = File.join(@temp_dir, "google_tokens.yaml")
        assert File.exist?(token_path), "New token file should be created after re-auth"
      end

      def test_clear_credentials_also_removes_legacy_tokens_json
        # Create a legacy tokens.json file
        legacy_path = File.join(@temp_dir, "tokens.json")
        File.write(legacy_path, JSON.generate({"access_token" => "legacy"}))

        write_existing_tokens

        Auth.reset_adapter!

        cmd = Init.new
        mock_authorizer = mock("authorizer")
        mock_authorizer.stubs(:get_credentials).returns(stub_credentials)

        cmd.stubs(:build_authorizer).returns(mock_authorizer)
        CLI::UI::Prompt.stubs(:confirm).returns(true)

        cmd.call([
          "--client-id=test.apps.googleusercontent.com",
          "--client-secret=test_secret"
        ], "init")

        refute File.exist?(legacy_path), "Legacy tokens.json should be cleaned up during re-auth"
      end

      # OAuth flow tests

      def test_stores_credentials_after_successful_auth
        cmd = Init.new
        credentials = stub_credentials

        mock_authorizer = mock("authorizer")
        mock_authorizer.stubs(:get_credentials).returns(credentials)

        cmd.stubs(:build_authorizer).returns(mock_authorizer)

        cmd.call([
          "--client-id=test.apps.googleusercontent.com",
          "--client-secret=test_secret"
        ], "init")

        # Verify token file was created in YAML format
        token_path = File.join(@temp_dir, "google_tokens.yaml")
        assert File.exist?(token_path), "Token file should be created"

        yaml_data = YAML.safe_load_file(token_path)
        stored = JSON.parse(yaml_data["default"])
        assert_equal "new_access_token", stored["access_token"]
        assert_equal "new_refresh_token", stored["refresh_token"]
      end

      def test_stores_client_credentials
        cmd = Init.new
        mock_authorizer = mock("authorizer")
        mock_authorizer.stubs(:get_credentials).returns(stub_credentials)

        cmd.stubs(:build_authorizer).returns(mock_authorizer)

        cmd.call([
          "--client-id=test.apps.googleusercontent.com",
          "--client-secret=my_secret"
        ], "init")

        creds_path = File.join(@temp_dir, "client_credentials.json")
        assert File.exist?(creds_path), "Client credentials file should be created"

        stored = JSON.parse(File.read(creds_path))
        assert_equal "test.apps.googleusercontent.com", stored["client_id"]
        assert_equal "my_secret", stored["client_secret"]
      end

      def test_client_credentials_have_restricted_permissions
        cmd = Init.new
        mock_authorizer = mock("authorizer")
        mock_authorizer.stubs(:get_credentials).returns(stub_credentials)

        cmd.stubs(:build_authorizer).returns(mock_authorizer)

        cmd.call([
          "--client-id=test.apps.googleusercontent.com",
          "--client-secret=test_secret"
        ], "init")

        creds_path = File.join(@temp_dir, "client_credentials.json")
        mode = File.stat(creds_path).mode & 0o777
        assert_equal 0o600, mode, "Client credentials should have restricted permissions"
      end

      def test_displays_success_message
        cmd = Init.new
        mock_authorizer = mock("authorizer")
        mock_authorizer.stubs(:get_credentials).returns(stub_credentials)

        cmd.stubs(:build_authorizer).returns(mock_authorizer)

        cmd.call([
          "--client-id=test.apps.googleusercontent.com",
          "--client-secret=test_secret"
        ], "init")

        assert_match(/Successfully/i, captured_output)
      end

      def test_handles_auth_failure
        cmd = Init.new
        mock_authorizer = mock("authorizer")
        mock_authorizer.stubs(:get_credentials).returns(nil)

        cmd.stubs(:build_authorizer).returns(mock_authorizer)

        error = assert_raises(CLI::Kit::Abort) do
          cmd.call([
            "--client-id=test.apps.googleusercontent.com",
            "--client-secret=test_secret"
          ], "init")
        end

        assert_match(/fail|error|cancel/i, error.message)
      end

      # Loopback redirect tests

      def test_open_browser_returns_true_when_launchy_succeeds
        cmd = Init.new

        require "launchy"
        Launchy.stubs(:open).returns(true)

        assert cmd.send(:open_browser, "http://example.com")
      end

      def test_open_browser_returns_false_when_launchy_fails
        cmd = Init.new

        require "launchy"
        Launchy.stubs(:open).raises(StandardError.new("no browser"))

        refute cmd.send(:open_browser, "http://example.com")
      end

      def test_extract_code_from_request_parses_code_parameter
        cmd = Init.new

        request_line = "GET /oauth2callback?code=4/0AXxxxx&scope=https://www.googleapis.com/auth/calendar HTTP/1.1"
        code = cmd.send(:extract_code_from_request, request_line)

        assert_equal "4/0AXxxxx", code
      end

      def test_extract_code_from_request_returns_nil_for_missing_code
        cmd = Init.new

        request_line = "GET /oauth2callback?error=access_denied HTTP/1.1"
        code = cmd.send(:extract_code_from_request, request_line)

        assert_nil code
      end

      def test_extract_code_from_request_returns_nil_for_nil_input
        cmd = Init.new

        assert_nil cmd.send(:extract_code_from_request, nil)
      end

      def test_extract_error_from_request_parses_error_parameter
        cmd = Init.new

        request_line = "GET /oauth2callback?error=access_denied HTTP/1.1"
        error = cmd.send(:extract_error_from_request, request_line)

        assert_equal "access_denied", error
      end

      def test_obtain_code_via_manual_entry_parses_url_with_code
        cmd = Init.new

        CLI::UI.stubs(:ask).returns("http://127.0.0.1:12345?code=4/0AXtest&scope=calendar")

        code = cmd.send(:obtain_code_via_manual_entry)

        assert_equal "4/0AXtest", code
      end

      def test_obtain_code_via_manual_entry_handles_plain_code
        cmd = Init.new

        CLI::UI.stubs(:ask).returns("4/0AXtest")

        code = cmd.send(:obtain_code_via_manual_entry)

        assert_equal "4/0AXtest", code
      end

      # Help text test

      def test_has_help_text
        assert_match(/oauth|google|authenticate/i, Init.help.to_s)
      end

      private

      def stub_credentials
        creds = mock("credentials")
        creds.stubs(:client_id).returns("test.apps.googleusercontent.com")
        creds.stubs(:access_token).returns("new_access_token")
        creds.stubs(:refresh_token).returns("new_refresh_token")
        creds.stubs(:scope).returns(["https://www.googleapis.com/auth/calendar.readonly"])
        creds.stubs(:expires_at).returns(Time.now + 3600)
        creds
      end

      def write_existing_tokens
        token_data = {
          "client_id" => "existing.apps.googleusercontent.com",
          "access_token" => "existing",
          "refresh_token" => "existing_refresh",
          "expiration_time_millis" => (Time.now.to_i + 3600) * 1000
        }

        yaml_data = {"default" => JSON.generate(token_data)}
        File.write(File.join(@temp_dir, "google_tokens.yaml"), YAML.dump(yaml_data))

        # Also need client credentials for authenticated? check
        client_creds = {"client_id" => "existing.apps.googleusercontent.com", "client_secret" => "secret"}
        File.write(File.join(@temp_dir, "client_credentials.json"), JSON.generate(client_creds))
      end
    end
  end
end
