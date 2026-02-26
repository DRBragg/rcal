require "json"
require "socket"
require "uri"
require "rcal"
require "googleauth"
require "googleauth/stores/file_token_store"
require_relative "../auth"
require_relative "../adapters/auth/google"

module Rcal
  module Commands
    class Init < Rcal::Command
      CALLBACK_PATH = "/oauth2callback"
      LISTEN_ADDRESS = "127.0.0.1"

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
          file: Auth.token_path
        )

        redirect_uri = start_loopback_server

        authorizer = Google::Auth::UserAuthorizer.new(
          client_id_obj,
          Adapters::Auth::Google::SCOPES,
          token_store,
          callback_uri: redirect_uri
        )

        # Check if we already have credentials
        credentials = authorizer.get_credentials("default")
        if credentials
          stop_loopback_server
          return authorizer
        end

        # Need to perform OAuth flow
        url = authorizer.get_authorization_url(base_url: redirect_uri)

        puts CLI::UI.fmt("{{bold:Open this URL in your browser to authorize rcal:}}")
        puts ""
        puts url
        puts ""

        code = obtain_authorization_code(url)

        if code.nil? || code.empty?
          stop_loopback_server
          raise CLI::Kit::Abort, "No authorization code received."
        end

        authorizer.get_and_store_credentials_from_code(
          user_id: "default",
          code: code,
          base_url: redirect_uri
        )

        authorizer
      ensure
        stop_loopback_server
      end

      def start_loopback_server
        @server = TCPServer.new(LISTEN_ADDRESS, 0)
        port = @server.addr[1]
        "http://#{LISTEN_ADDRESS}:#{port}"
      end

      def stop_loopback_server
        @server&.close
        @server = nil
      rescue IOError
        @server = nil
      end

      def obtain_authorization_code(url)
        browser_opened = open_browser(url)

        if browser_opened
          obtain_code_via_loopback
        else
          obtain_code_via_manual_entry
        end
      end

      # Wait for Google to redirect back to our loopback server and
      # extract the authorization code from the request.
      def obtain_code_via_loopback
        puts CLI::UI.fmt("{{info:Waiting for authorization in your browser...}}")

        client = @server.accept
        request_line = client.gets

        # Parse the code from the GET request
        code = extract_code_from_request(request_line)

        if code
          client.print "HTTP/1.1 200 OK\r\n"
          client.print "Content-Type: text/html\r\n"
          client.print "\r\n"
          client.print success_html
        else
          error = extract_error_from_request(request_line)
          client.print "HTTP/1.1 200 OK\r\n"
          client.print "Content-Type: text/html\r\n"
          client.print "\r\n"
          client.print failure_html(error)
        end

        client.close
        code
      end

      # For headless environments: ask the user to paste the redirect URL
      # from their browser's address bar after authorizing.
      def obtain_code_via_manual_entry
        puts ""
        puts CLI::UI.fmt("{{bold:After authorizing, your browser will redirect to a localhost URL.}}")
        puts CLI::UI.fmt("{{bold:Copy the full URL from your browser's address bar and paste it here:}}")
        response = CLI::UI.ask("")

        # The user may paste a full URL or just the code
        if response.include?("code=")
          uri = URI.parse(response)
          params = URI.decode_www_form(uri.query || "")
          params.assoc("code")&.last
        else
          response.strip
        end
      rescue URI::InvalidURIError
        # If the URL can't be parsed, try treating the whole thing as a code
        response&.strip
      end

      def extract_code_from_request(request_line)
        return nil unless request_line

        path = request_line.split(" ")[1]
        return nil unless path

        uri = URI.parse("http://localhost#{path}")
        params = URI.decode_www_form(uri.query || "")
        params.assoc("code")&.last
      rescue URI::InvalidURIError
        nil
      end

      def extract_error_from_request(request_line)
        return "Unknown error" unless request_line

        path = request_line.split(" ")[1]
        return "Unknown error" unless path

        uri = URI.parse("http://localhost#{path}")
        params = URI.decode_www_form(uri.query || "")
        params.assoc("error")&.last || "Unknown error"
      rescue URI::InvalidURIError
        "Unknown error"
      end

      def success_html
        <<~HTML
          <html><body>
            <h1>Authorization successful!</h1>
            <p>You can close this window and return to rcal.</p>
          </body></html>
        HTML
      end

      def failure_html(error)
        <<~HTML
          <html><body>
            <h1>Authorization failed</h1>
            <p>Error: #{error}</p>
            <p>Please try again with <code>rcal init</code>.</p>
          </body></html>
        HTML
      end

      def open_browser(url)
        require "launchy"
        Launchy.open(url)
        true
      rescue LoadError, StandardError
        false
      end

      def store_client_credentials(client_id, client_secret)
        credentials_file = Auth.client_credentials_path
        data = {"client_id" => client_id, "client_secret" => client_secret}
        File.write(credentials_file, JSON.generate(data))
        File.chmod(0o600, credentials_file)
      end
    end
  end
end
