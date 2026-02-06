require "test_helper"
require "rcal/auth"

module Rcal
  class AuthTest < Minitest::Test
    def setup
      Auth.reset_adapter!
    end

    def teardown
      Auth.reset_adapter!
    end

    def test_store_credentials_delegates_to_adapter
      mock_adapter = mock("auth_adapter")
      credentials = stub("credentials")
      mock_adapter.expects(:store_credentials).with(credentials)

      Auth.adapter = mock_adapter
      Auth.store_credentials(credentials)
    end

    def test_load_credentials_delegates_to_adapter
      mock_adapter = mock("auth_adapter")
      mock_adapter.expects(:load_credentials).returns({"access_token" => "test"})

      Auth.adapter = mock_adapter
      result = Auth.load_credentials

      assert_equal({"access_token" => "test"}, result)
    end

    def test_authenticated_delegates_to_adapter
      mock_adapter = mock("auth_adapter")
      mock_adapter.expects(:authenticated?).returns(true)

      Auth.adapter = mock_adapter

      assert Auth.authenticated?
    end

    def test_token_expired_delegates_to_adapter
      mock_adapter = mock("auth_adapter")
      mock_adapter.expects(:token_expired?).returns(false)

      Auth.adapter = mock_adapter

      refute Auth.token_expired?
    end

    def test_clear_credentials_delegates_to_adapter
      mock_adapter = mock("auth_adapter")
      mock_adapter.expects(:clear_credentials)

      Auth.adapter = mock_adapter
      Auth.clear_credentials
    end

    def test_uses_default_google_adapter
      assert_instance_of Adapters::Auth::Google, Auth.adapter
    end

    def test_allows_custom_adapter
      custom_adapter = Object.new
      Auth.adapter = custom_adapter

      assert_same custom_adapter, Auth.adapter
    end

    def test_reset_adapter_restores_default
      custom_adapter = Object.new
      Auth.adapter = custom_adapter

      Auth.reset_adapter!

      assert_instance_of Adapters::Auth::Google, Auth.adapter
    end
  end
end
