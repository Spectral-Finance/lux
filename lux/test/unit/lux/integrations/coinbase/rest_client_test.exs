defmodule Lux.Integrations.Coinbase.RestClientTest do
  use UnitCase, async: true

  alias Lux.Integrations.Coinbase.RestClient

  @config %{
    api_key: "test_key",
    secret_key: "test_secret",
    sandbox?: false
  }

  describe "base_url/1" do
    test "returns production and sandbox URLs" do
      assert RestClient.base_url(false) == "https://api.coinbase.com"
      assert RestClient.base_url(true) == "https://api-public.sandbox.exchange.coinbase.com"
    end
  end

  describe "prepare_signed_get/3" do
    test "formats signed GET url and auth headers" do
      {url, headers} = RestClient.prepare_signed_get(@config, "/api/v3/brokerage/products", %{limit: 10})

      assert String.starts_with?(url, "https://api.coinbase.com/api/v3/brokerage/products?limit=10")
      assert {"CB-ACCESS-KEY", "test_key"} in headers
      assert Enum.any?(headers, fn {k, _} -> k == "CB-ACCESS-SIGN" end)
    end
  end

  describe "prepare_signed_post/3" do
    test "formats signed POST url, body, and auth headers" do
      payload = %{"client_order_id" => "12345", "product_id" => "BTC-USD"}
      {url, body, headers} = RestClient.prepare_signed_post(@config, "/api/v3/brokerage/orders", payload)

      assert url == "https://api.coinbase.com/api/v3/brokerage/orders"
      assert is_binary(body)
      assert String.contains?(body, "BTC-USD")
      assert {"CB-ACCESS-KEY", "test_key"} in headers
    end
  end

  describe "parse_response/1" do
    test "parses successful payload" do
      assert {:ok, %{"success" => true}} = RestClient.parse_response({:ok, %{"success" => true}})
    end

    test "parses coinbase error" do
      err = %{"error" => "INVALID_ARGUMENT", "message" => "Price cannot be zero"}
      assert {:error, %{error: "INVALID_ARGUMENT", message: "Price cannot be zero"}} =
               RestClient.parse_response({:ok, err})
    end
  end
end
