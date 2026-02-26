module Rcal
  module Adapters
    module Auth
      class Base
        def store_credentials(credentials)
          raise NotImplementedError, "#{self.class} must implement #store_credentials"
        end

        def load_credentials
          raise NotImplementedError, "#{self.class} must implement #load_credentials"
        end

        def load_client_credentials
          raise NotImplementedError, "#{self.class} must implement #load_client_credentials"
        end

        def authenticated?
          raise NotImplementedError, "#{self.class} must implement #authenticated?"
        end

        def token_expired?
          raise NotImplementedError, "#{self.class} must implement #token_expired?"
        end

        def clear_credentials
          raise NotImplementedError, "#{self.class} must implement #clear_credentials"
        end

        def token_path
          raise NotImplementedError, "#{self.class} must implement #token_path"
        end

        def client_credentials_path
          raise NotImplementedError, "#{self.class} must implement #client_credentials_path"
        end
      end
    end
  end
end
