defmodule Lux.Integrations.CoinbaseTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Coinbase

  describe "request_settings/0" do
    test "returns auth configuration" do
      settings = Coinbase.request_settings()
      assert settings.auth.type == :custom
      assert settings.auth.auth_function == &Coinbase.add_auth_headers/1
    end
  end

  describe "add_auth_headers/1" do
    test "includes required Coinbase headers" do
      opts = [method: "GET", path: "/accounts", body: ""]
      headers = Coinbase.add_auth_headers(opts)

      header_keys = Enum.map(headers, fn {k, _} -> k end)
      assert "CB-ACCESS-KEY" in header_keys
      assert "CB-ACCESS-SIGN" in header_keys
      assert "CB-ACCESS-TIMESTAMP" in header_keys
      assert "CB-ACCESS-PASSPHRASE" in header_keys
    end
  end

  describe "ws_subscribe/2" do
    test "builds valid subscription message" do
      msg = Coinbase.ws_subscribe(["BTC-USD"])
      decoded = Jason.decode!(msg)

      assert decoded["type"] == "subscribe"
      assert "BTC-USD" in decoded["product_ids"]
      assert "ticker" in decoded["channels"]
    end
  end

  describe "rate_limit_info/0" do
    test "returns rate limit configuration" do
      info = Coinbase.rate_limit_info()
      assert info.public_limit == 15
      assert info.private_limit == 5
    end
  end
end
