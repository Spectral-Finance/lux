defmodule Lux.Binance.AuthTest do
  use ExUnit.Case, async: true
  alias Lux.Binance.Auth

  @binance_secret "NhqPtMDL5cvBxT3a65KSTBmUzaw9M6PZ18fLiNFZw9z86St0695BWkTxzYD6dAe3"

  describe "sign/2 & hmac_sha256/2" do
    test "matches official Binance documentation test vector exactly" do
      query_string =
        "symbol=LTCBTC&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1&price=0.1&recvWindow=5000&timestamp=1499827319559"

      expected_signature =
        "f55ff10f03a74820691943ff17ce0bbf5bc8f5bc275e619c0977c5c71ba4d5a9"

      signature = Auth.sign(query_string, @binance_secret)
      assert signature == expected_signature

      assert Auth.hmac_sha256(@binance_secret, query_string) == expected_signature
    end
  end

  describe "sign_params/3" do
    test "correctly signs an ordered keyword list parameter list matching test vector" do
      params = [
        symbol: "LTCBTC",
        side: "BUY",
        type: "LIMIT",
        timeInForce: "GTC",
        quantity: "1",
        price: "0.1",
        recvWindow: 5000,
        timestamp: 1499827319559
      ]

      signed = Auth.sign_params(params, @binance_secret)

      assert signed[:signature] ==
               "f55ff10f03a74820691943ff17ce0bbf5bc8f5bc275e619c0977c5c71ba4d5a9"
    end

    test "correctly signs a parameter map" do
      params = %{
        symbol: "LTCBTC",
        side: "BUY",
        type: "LIMIT",
        timeInForce: "GTC",
        quantity: "1",
        price: "0.1",
        recvWindow: 5000,
        timestamp: 1499827319559
      }

      signed = Auth.sign_params(params, @binance_secret)

      assert signed[:signature] ==
               "309283bae93927d3ac2a62c8fe2030238d02e914fc802e5dab819aced58b234b"
    end

    test "appends default timestamp and recvWindow if missing" do
      params = %{symbol: "BTCUSDT", side: "BUY", type: "MARKET", quantity: "0.1"}
      signed = Auth.sign_params(params, @binance_secret, 6000)

      assert Map.has_key?(signed, :timestamp) or Map.has_key?(signed, "timestamp")
      assert signed[:recvWindow] == 6000 or signed["recvWindow"] == 6000
      assert is_binary(signed[:signature] || signed["signature"])
    end

    test "signs binary string payload" do
      payload = "symbol=BTCUSDT&timestamp=1600000000000"
      signed_payload = Auth.sign_params(payload, "secret_key")

      assert String.starts_with?(signed_payload, payload)
      assert signed_payload =~ "&signature="
    end
  end

  describe "headers/1" do
    test "returns X-MBX-APIKEY header when key is provided" do
      assert Auth.headers("my_api_key") == [{"X-MBX-APIKEY", "my_api_key"}]
      assert Auth.headers(nil) == []
    end
  end
end
