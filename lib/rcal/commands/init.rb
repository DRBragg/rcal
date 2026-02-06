require "json"
require "rcal"
require "googleauth"
require "googleauth/stores/file_token_store"
require_relative "../auth"

module Rcal
  module Commands
    class Init < Rcal::Command
      SCOPES = [
        "https://www.googleapis.com/auth/calendar.readonly",
        "https://www.googleapis.com/auth/calendar.events"
      ].freeze

      OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze

      def self.help
        <<~HELP
          Authenticate with Google Calendar using OAuth.

          Usage: rcal init --client-id=ID --client-secret=SECRET

          Required:
            --client-id=ID        OAuth client ID from Google Cloud Console
            --client-secret=SECRET  OAuth client secret from Google Cloud Console

          To get credentials:
            1. Go to https://console.cloud.google.com/apis/credentials
            2. Create OAuth 2.0 Client ID (Desktop app)
            3. Download or copy the client ID and secret

          Examples:
            rcal init --client-id=123.apps.googleusercontent.com --client-secret=GOCSPX-xxx
        HELP
      end

      def run(args, _name)
        client_id, client_secret = parse_args(args)

        validate_credentials!(client_id, client_secret)
        ensure_data_directory!

        if Auth.authenticated?
          return unless confirm_reauth?
          Auth.clear_credentials
        end

        credentials = authorize(client_id, client_secret)

        if credentials.nil?
          raise CLI::Kit::Abort, "Authentication failed or was cancelled."
        end

        Auth.store_credentials(credentials)
        store_client_credentials(client_id, client_secret)

        puts CLI::UI.fmt("{{v}} Successfully authenticated with Google Calendar!")
      end

      private

      def parse_args(args)
        client_id = nil
        client_secret = nil

        args.each do |arg|
          if arg.start_with?("--client-id=")
            client_id = arg.sub("--client-id=", "")
          elsif arg.start_with?("--client-secret=")
            client_secret = arg.sub("--client-secret=", "")
          end
        end

        [client_id, client_secret]
      end

      def validate_credentials!(client_id, client_secret)
        if client_id.nil? || client_id.empty?
          raise CLI::Kit::Abort, "Missing required argument: --client-id\n" \
            "Get your OAuth client ID from Google Cloud Console."
        end

        if client_secret.nil? || client_secret.empty?
          raise CLI::Kit::Abort, "Missing required argument: --client-secret\n" \
            "Get your OAuth client secret from Google Cloud Console."
        end
      end

      def ensure_data_directory!
        dir = Rcal::Configuration.data_dir
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
      end

      def confirm_reauth?
        puts CLI::UI.fmt("{{yellow:You are already authenticated.}}")
        CLI::UI::Prompt.confirm("Re-authenticate?")
      end

      def authorize(client_id, client_secret)
        build_authorizer(client_id, client_secret).get_credentials("default")
      end

      def build_authorizer(client_id, client_secret)
        client_id_obj = Google::Auth::ClientId.new(client_id, client_secret)

        token_store = Google::Auth::Stores::FileTokenStore.new(
          file: File.join(Rcal::Configuration.data_dir, "google_tokens.yaml")
        )

        authorizer = Google::Auth::UserAuthorizer.new(
          client_id_obj,
          SCOPES,
          token_store
        )

        # Check if we already have credentials
        credentials = authorizer.get_credentials("default")
        return authorizer if credentials

        # Need to perform OAuth flow
        url = authorizer.get_authorization_url(base_url: OOB_URI)

        puts CLI::UI.fmt("{{bold:Open this URL in your browser to authorize rcal:}}")
        puts ""
        puts url
        puts ""

        # Open browser automatically if possible
        open_browser(url)

        puts CLI::UI.fmt("{{bold:Enter the authorization code:}}")
        code = CLI::UI.ask("")

        authorizer.get_and_store_credentials_from_code(
          user_id: "default",
          code: code,
          base_url: OOB_URI
        )

        authorizer
      end

      def open_browser(url)
        require "launchy"
        Launchy.open(url)
      rescue LoadError, StandardError
        # Launchy not available or failed, user will need to copy URL manually
      end

      def store_client_credentials(client_id, client_secret)
        credentials_file = File.join(Rcal::Configuration.data_dir, "client_credentials.json")
        data = {"client_id" => client_id, "client_secret" => client_secret}
        File.write(credentials_file, JSON.generate(data))
        File.chmod(0o600, credentials_file)
      end
    end
  end
end
