defmodule Lux.Integrations.Binance.SignerTest do
  use UnitCase, async: true

  alias Lux.Integrations.Binance.Signer

  @test_secret "nbR42Wd7hQo0zX1E8c5aT6vY3uI9pL0mK2jH5gF8dD1sA4eG7"
  @test_key "vmPUZE6mv9SD5VNHk4HlWFsOr6aKE2zvsw0MuIgwCIPy6utIco14y7Ju91duEh8A"

  describe "sign/2" do
    test "generates valid HMAC-SHA256 hex digest" do
      query = "symbol=LTCBTC&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1&price=0.1&recvWindow=5000&timestamp=1499827319559"
      signature = Signer.sign(query, @test_secret)

      assert is_binary(signature)
      assert String.length(signature) == 64
      assert signature =~ ~r/^[a-f0-9]{64}$/
    end
  end

  describe "prepare_signed_query/4" do
    test "appends timestamp, recvWindow, and signature" do
      params = %{symbol: "BTCUSDT", side: "BUY", quantity: 0.5}
      signed_query = Signer.prepare_signed_query(params, @test_secret, 1_600_000_000_000, 5000)

      assert String.contains?(signed_query, "symbol=BTCUSDT")
      assert String.contains?(signed_query, "timestamp=1600000000000")
      assert String.contains?(signed_query, "recvWindow=5000")
      assert String.contains?(signed_query, "signature=")
    end
  end

  describe "auth_headers/1" do
    test "formats binance request headers" do
      headers = Signer.auth_headers(@test_key)
      assert {"X-MBX-APIKEY", @test_key} in headers
      assert {"Content-Type", "application/x-www-form-urlencoded"} in headers
    end
  end
end
