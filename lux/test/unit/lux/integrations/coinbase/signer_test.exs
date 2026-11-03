defmodule Lux.Integrations.Coinbase.SignerTest do
  use UnitCase, async: true

  alias Lux.Integrations.Coinbase.Signer

  @test_key "organizations/{org_id}/apiKeys/{key_id}"
  @test_secret "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg"

  describe "sign/5" do
    test "generates valid hex signature for message" do
      ts = "1700000000"
      method = "GET"
      path = "/api/v3/brokerage/accounts"
      body = ""

      signature = Signer.sign(ts, method, path, body, @test_secret)

      assert is_binary(signature)
      assert String.length(signature) == 64
      assert signature =~ ~r/^[a-f0-9]{64}$/
    end
  end

  describe "auth_headers/6" do
    test "formats coinbase access headers" do
      headers = Signer.auth_headers(@test_key, @test_secret, "GET", "/api/v3/brokerage/orders", "", 1700000000)

      assert {"CB-ACCESS-KEY", @test_key} in headers
      assert {"CB-ACCESS-TIMESTAMP", "1700000000"} in headers
      assert {"Content-Type", "application/json"} in headers
      assert Enum.any?(headers, fn {k, _} -> k == "CB-ACCESS-SIGN" end)
    end
  end
end
