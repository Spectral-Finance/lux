defmodule Lux.Integrations.Binance.RestClientTest do
  use UnitCase, async: true

  alias Lux.Integrations.Binance.RestClient

  @config %{
    api_key: "sample_api_key",
    secret_key: "sample_secret_key",
    testnet?: false
  }

  describe "url builders" do
    test "returns production and testnet urls" do
      assert RestClient.spot_base_url(false) == "https://api.binance.com"
      assert RestClient.spot_base_url(true) == "https://testnet.binance.vision"
      assert RestClient.futures_base_url(false) == "https://fapi.binance.com"
      assert RestClient.futures_base_url(true) == "https://testnet.binancefuture.com"
    end
  end

  describe "prepare_signed_get/4" do
    test "formats signed get url and headers" do
      {url, headers} = RestClient.prepare_signed_get(@config, :spot, "/api/v3/account", %{})

      assert String.starts_with?(url, "https://api.binance.com/api/v3/account?")
      assert String.contains?(url, "signature=")
      assert {"X-MBX-APIKEY", "sample_api_key"} in headers
    end
  end

  describe "prepare_signed_post/4" do
    test "formats signed post url, body, and headers for futures" do
      params = %{symbol: "ETHUSDT", side: "BUY", quantity: 1.0}
      {url, body, headers} = RestClient.prepare_signed_post(@config, :futures, "/fapi/v1/order", params)

      assert url == "https://fapi.binance.com/fapi/v1/order"
      assert String.contains?(body, "symbol=ETHUSDT")
      assert String.contains?(body, "signature=")
      assert {"X-MBX-APIKEY", "sample_api_key"} in headers
    end
  end

  describe "parse_response/1" do
    test "parses successful payload" do
      assert {:ok, %{"status" => "FILLED"}} = RestClient.parse_response({:ok, %{"status" => "FILLED"}})
    end

    test "parses binance error code" do
      err = %{"code" => -2010, "msg" => "Account has insufficient balance for requested action."}
      assert {:error, %{code: -2010, message: "Account has insufficient balance for requested action."}} =
               RestClient.parse_response({:ok, err})
    end
  end
end
