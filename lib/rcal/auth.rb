require_relative "adapters/auth/google"
require_relative "config"

module Rcal
  class Auth
    class << self
      def store_credentials(credentials)
        adapter.store_credentials(credentials)
      end

      def load_credentials
        adapter.load_credentials
      end

      def authenticated?
        adapter.authenticated?
      end

      def token_expired?
        adapter.token_expired?
      end

      def clear_credentials
        adapter.clear_credentials
      end

      def adapter
        @adapter ||= default_adapter
      end

      attr_writer :adapter

      def reset_adapter!
        @adapter = nil
      end

      private

      def default_adapter
        Adapters::Auth::Google.new(
          token_path: File.join(Configuration.data_dir, "tokens.json")
        )
      end
    end
  end
end
