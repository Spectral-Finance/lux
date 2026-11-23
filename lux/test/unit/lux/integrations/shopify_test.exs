defmodule Lux.Integrations.ShopifyTest do
  @moduledoc """
  Test suite for the Shopify integration module.
  These tests verify:
  - Header management
  - Authentication configuration
  - Base URL / admin API URL construction
  - Access token resolution
  """

  use ExUnit.Case, async: false
  alias Lux.Integrations.Shopify

  setup do
    Application.put_env(:lux, Shopify,
      shop: "test-shop.myshopify.com",
      api_version: "2024-10",
      access_token: "test-token"
    )

    on_exit(fn ->
      Application.delete_env(:lux, Shopify)
    end)

    :ok
  end

  describe "shop/0" do
    test "returns the configured shop domain" do
      assert Shopify.shop() == "test-shop.myshopify.com"
    end
  end

  describe "api_version/0" do
    test "returns the configured API version" do
      assert Shopify.api_version() == "2024-10"
    end
  end

  describe "base_url/0" do
    test "builds the shop base URL" do
      assert Shopify.base_url() == "https://test-shop.myshopify.com"
    end
  end

  describe "admin_api_url/0" do
    test "builds the versioned admin API URL" do
      assert Shopify.admin_api_url() ==
               "https://test-shop.myshopify.com/admin/api/2024-10"
    end
  end

  describe "headers/0" do
    test "returns content-type and accept headers" do
      headers = Shopify.headers()
      assert {"Content-Type", "application/json"} in headers
      assert {"Accept", "application/json"} in headers
    end
  end

  describe "auth/0" do
    test "returns custom auth configuration" do
      auth = Shopify.auth()
      assert auth.type == :custom
      assert is_function(auth.auth_function, 1)
    end
  end

  describe "access_token/0" do
    test "returns the configured access token" do
      assert Shopify.access_token() == "test-token"
    end
  end

  describe "add_auth_header/1" do
    test "adds the X-Shopify-Access-Token header to a lens" do
      lens = %Lux.Lens{headers: [{"Content-Type", "application/json"}]}
      result = Shopify.add_auth_header(lens)
      assert {"X-Shopify-Access-Token", "test-token"} in result.headers
    end
  end
end