defmodule Lux.Web3.Auth.SiweMessageTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth.SiweMessage

  @valid_address "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

  test "creates SIWE message with defaults" do
    msg = SiweMessage.new(domain: "example.com", address: @valid_address, uri: "https://example.com")
    assert msg.domain == "example.com"
    assert msg.version == "1"
    assert msg.chain_id == 1
    assert String.length(msg.nonce) >= 8
  end

  test "generates EIP-4361 string" do
    msg = SiweMessage.new(
      domain: "example.com",
      address: @valid_address,
      uri: "https://example.com",
      nonce: "abc12345def67890",
      issued_at: "2026-01-01T00:00:00Z",
      statement: "Sign in to Example"
    )

    str = SiweMessage.to_string(msg)
    assert String.contains?(str, "example.com wants you to sign in with your Ethereum account:")
    assert String.contains?(str, @valid_address)
    assert String.contains?(str, "Sign in to Example")
    assert String.contains?(str, "Nonce: abc12345def67890")
  end

  test "parses EIP-4361 string" do
    msg = SiweMessage.new(
      domain: "app.example.com",
      address: @valid_address,
      uri: "https://app.example.com/login",
      nonce: "abcdef1234567890",
      issued_at: "2026-03-08T00:00:00Z",
      statement: "Please sign in"
    )

    str = SiweMessage.to_string(msg)
    {:ok, parsed} = SiweMessage.parse(str)
    assert parsed.domain == "app.example.com"
    assert parsed.address == @valid_address
    assert parsed.nonce == "abcdef1234567890"
  end

  test "validates valid message" do
    msg = SiweMessage.new(
      domain: "example.com",
      address: @valid_address,
      uri: "https://example.com",
      expiration_time: DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_iso8601()
    )
    assert :ok = SiweMessage.validate(msg)
  end

  test "validates expired message" do
    msg = SiweMessage.new(
      domain: "example.com",
      address: @valid_address,
      uri: "https://example.com",
      expiration_time: "2020-01-01T00:00:00Z"
    )
    assert {:error, :expired} = SiweMessage.validate(msg)
  end

  test "validates invalid address" do
    msg = SiweMessage.new(
      domain: "example.com",
      address: "not-an-address",
      uri: "https://example.com"
    )
    assert {:error, :invalid_address} = SiweMessage.validate(msg)
  end

  test "validates short nonce" do
    msg = %{SiweMessage.new(
      domain: "example.com",
      address: @valid_address,
      uri: "https://example.com"
    ) | nonce: "short"}
    assert {:error, :invalid_nonce} = SiweMessage.validate(msg)
  end

  test "generates unique nonces" do
    n1 = SiweMessage.generate_nonce()
    n2 = SiweMessage.generate_nonce()
    assert n1 != n2
    assert String.length(n1) >= 8
  end

  test "message with resources" do
    msg = SiweMessage.new(
      domain: "example.com",
      address: @valid_address,
      uri: "https://example.com",
      nonce: "abc12345def67890",
      issued_at: "2026-01-01T00:00:00Z",
      resources: ["https://example.com/tos", "ipfs://abc123"]
    )
    str = SiweMessage.to_string(msg)
    assert String.contains?(str, "Resources:")
    assert String.contains?(str, "- https://example.com/tos")
  end
end
