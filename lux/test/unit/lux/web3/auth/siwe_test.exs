defmodule Lux.Web3.Auth.SiweTest do
  use UnitCase, async: true

  alias Lux.Web3.Auth.Siwe

  @address "0x71C7656EC7ab88b098defB751B7401B5f6d8976F"
  @message """
  app.example.com wants you to sign in with your Ethereum account:
  #{@address}

  Sign in to Lux.

  URI: https://app.example.com/login
  Version: 1
  Chain ID: 1
  Nonce: n-123456
  Issued At: 2026-06-15T10:00:00Z
  Expiration Time: 2026-06-15T11:00:00Z
  Resources:
  - https://app.example.com/orders
  """

  test "parses an EIP-4361 SIWE message" do
    assert {:ok, siwe} = Siwe.parse(@message)
    assert siwe.domain == "app.example.com"
    assert siwe.address == String.downcase(@address)
    assert siwe.statement == "Sign in to Lux."
    assert siwe.uri == "https://app.example.com/login"
    assert siwe.version == "1"
    assert siwe.chain_id == 1
    assert siwe.nonce == "n-123456"
    assert siwe.resources == ["https://app.example.com/orders"]
  end

  test "validates expected domain uri nonce chain and time window" do
    assert {:ok, _siwe} =
             Siwe.validate(@message,
               domain: "app.example.com",
               uri: "https://app.example.com/login",
               nonce: "n-123456",
               chain_ids: [1, 10],
               now: ~U[2026-06-15 10:30:00Z]
             )
  end

  test "rejects replay and expired messages" do
    assert {:error, "SIWE nonce mismatch"} = Siwe.validate(@message, nonce: "wrong")
    assert {:error, "SIWE message has expired"} = Siwe.validate(@message, now: ~U[2026-06-15 11:00:01Z])
  end

  test "rejects malformed messages" do
    assert {:error, "Invalid SIWE domain line"} = Siwe.parse("not a siwe message")
  end
end
