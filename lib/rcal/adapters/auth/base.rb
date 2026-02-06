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

        def authenticated?
          raise NotImplementedError, "#{self.class} must implement #authenticated?"
        end

        def token_expired?
          raise NotImplementedError, "#{self.class} must implement #token_expired?"
        end

        def clear_credentials
          raise NotImplementedError, "#{self.class} must implement #clear_credentials"
        end
      end
    end
  end
end
