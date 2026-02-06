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
        # Create existing token file
        token_path = File.join(@temp_dir, "tokens.json")
        FileUtils.mkdir_p(File.dirname(token_path))
        File.write(token_path, JSON.generate({
          "access_token" => "existing",
          "refresh_token" => "existing_refresh",
          "expires_at" => (Time.now + 3600).to_i
        }))

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
        # Create existing token file
        token_path = File.join(@temp_dir, "tokens.json")
        FileUtils.mkdir_p(File.dirname(token_path))
        File.write(token_path, JSON.generate({
          "access_token" => "existing",
          "refresh_token" => "existing_refresh",
          "expires_at" => (Time.now + 3600).to_i
        }))

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

        # Verify token file was created
        token_path = File.join(@temp_dir, "tokens.json")
        assert File.exist?(token_path), "Token file should be created"

        stored = JSON.parse(File.read(token_path))
        assert_equal "new_access_token", stored["access_token"]
        assert_equal "new_refresh_token", stored["refresh_token"]
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

      # Help text test

      def test_has_help_text
        assert_match(/oauth|google|authenticate/i, Init.help.to_s)
      end

      private

      def stub_credentials
        creds = mock("credentials")
        creds.stubs(:access_token).returns("new_access_token")
        creds.stubs(:refresh_token).returns("new_refresh_token")
        creds.stubs(:expires_at).returns(Time.now + 3600)
        creds
      end
    end
  end
end
