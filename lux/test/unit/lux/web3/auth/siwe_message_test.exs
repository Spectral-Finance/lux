defmodule Lux.Web3.Auth.SIWEMessageTest do
  @moduledoc """
  Tests for the SIWEMessage module covering EIP-4361 message creation,
  parsing, validation, and serialization.
  """

  use UnitCase, async: true

  alias Lux.Web3.Auth.SIWEMessage

  @valid_address "0x71C7656EC7ab88b098defB751B7401B5f6d8976F"
  @valid_attrs %{
    domain: "example.com",
    address: @valid_address,
    statement: "Sign in to Example App",
    uri: "https://example.com/login",
    version: "1",
    chain_id: 1,
    nonce: "abc123def456ghij",
    issued_at: ~U[2024-01-01 00:00:00Z]
  }

  describe "new/1" do
    test "creates a valid SIWE message with all required fields" do
      assert {:ok, msg} = SIWEMessage.new(@valid_attrs)
      assert msg.domain == "example.com"
      assert msg.address == @valid_address
      assert msg.statement == "Sign in to Example App"
      assert msg.uri == "https://example.com/login"
      assert msg.version == "1"
      assert msg.chain_id == 1
      assert msg.nonce == "abc123def456ghij"
      assert msg.issued_at == ~U[2024-01-01 00:00:00Z]
      assert msg.resources == []
    end

    test "creates a message with optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          expiration_time: ~U[2024-01-02 00:00:00Z],
          not_before: ~U[2024-01-01 00:00:00Z],
          request_id: "req-123",
          resources: ["https://example.com/api", "ipfs://abc"]
        })

      assert {:ok, msg} = SIWEMessage.new(attrs)
      assert msg.expiration_time == ~U[2024-01-02 00:00:00Z]
      assert msg.not_before == ~U[2024-01-01 00:00:00Z]
      assert msg.request_id == "req-123"
      assert msg.resources == ["https://example.com/api", "ipfs://abc"]
    end

    test "defaults version to nil-safe handling" do
      attrs = Map.put(@valid_attrs, :version, nil)
      assert {:ok, msg} = SIWEMessage.new(attrs)
      assert msg.version == "1"
    end

    test "rejects missing domain" do
      attrs = Map.delete(@valid_attrs, :domain)
      assert {:error, "domain is required"} = SIWEMessage.new(attrs)
    end

    test "rejects empty domain" do
      attrs = Map.put(@valid_attrs, :domain, "")
      assert {:error, "domain cannot be empty"} = SIWEMessage.new(attrs)
    end

    test "rejects missing address" do
      attrs = Map.delete(@valid_attrs, :address)
      assert {:error, "address is required"} = SIWEMessage.new(attrs)
    end

    test "rejects invalid address format" do
      attrs = Map.put(@valid_attrs, :address, "not-an-address")
      assert {:error, "invalid Ethereum address format"} = SIWEMessage.new(attrs)
    end

    test "rejects address without 0x prefix" do
      attrs = Map.put(@valid_attrs, :address, "71C7656EC7ab88b098defB751B7401B5f6d8976F")
      assert {:error, "invalid Ethereum address format"} = SIWEMessage.new(attrs)
    end

    test "rejects address with wrong length" do
      attrs = Map.put(@valid_attrs, :address, "0x71C7656EC7ab88b098defB751B7401B5f6d897")
      assert {:error, "invalid Ethereum address format"} = SIWEMessage.new(attrs)
    end

    test "rejects missing uri" do
      attrs = Map.delete(@valid_attrs, :uri)
      assert {:error, "uri is required"} = SIWEMessage.new(attrs)
    end

    test "rejects invalid version" do
      attrs = Map.put(@valid_attrs, :version, "2")
      assert {:error, "version must be \"1\""} = SIWEMessage.new(attrs)
    end

    test "rejects missing chain_id" do
      attrs = Map.delete(@valid_attrs, :chain_id)
      assert {:error, "chain_id is required"} = SIWEMessage.new(attrs)
    end

    test "rejects non-positive chain_id" do
      attrs = Map.put(@valid_attrs, :chain_id, 0)
      assert {:error, "chain_id must be a positive integer"} = SIWEMessage.new(attrs)
    end

    test "rejects missing nonce" do
      attrs = Map.delete(@valid_attrs, :nonce)
      assert {:error, "nonce is required"} = SIWEMessage.new(attrs)
    end

    test "rejects short nonce" do
      attrs = Map.put(@valid_attrs, :nonce, "abc")
      assert {:error, "nonce must be at least 8 characters"} = SIWEMessage.new(attrs)
    end

    test "rejects missing issued_at" do
      attrs = Map.delete(@valid_attrs, :issued_at)
      assert {:error, "issued_at is required"} = SIWEMessage.new(attrs)
    end

    test "rejects non-DateTime issued_at" do
      attrs = Map.put(@valid_attrs, :issued_at, "2024-01-01")
      assert {:error, "issued_at must be a DateTime"} = SIWEMessage.new(attrs)
    end
  end

  describe "to_string/1" do
    test "serializes a basic SIWE message" do
      {:ok, msg} = SIWEMessage.new(@valid_attrs)
      str = SIWEMessage.to_string(msg)

      assert str =~ "example.com wants you to sign in with your Ethereum account:"
      assert str =~ @valid_address
      assert str =~ "Sign in to Example App"
      assert str =~ "URI: https://example.com/login"
      assert str =~ "Version: 1"
      assert str =~ "Chain ID: 1"
      assert str =~ "Nonce: abc123def456ghij"
      assert str =~ "Issued At: 2024-01-01T00:00:00Z"
    end

    test "includes optional fields when present" do
      attrs =
        Map.merge(@valid_attrs, %{
          expiration_time: ~U[2024-01-02 00:00:00Z],
          not_before: ~U[2024-01-01 00:00:00Z],
          request_id: "req-123",
          resources: ["https://example.com/api"]
        })

      {:ok, msg} = SIWEMessage.new(attrs)
      str = SIWEMessage.to_string(msg)

      assert str =~ "Expiration Time: 2024-01-02T00:00:00Z"
      assert str =~ "Not Before: 2024-01-01T00:00:00Z"
      assert str =~ "Request ID: req-123"
      assert str =~ "Resources:"
      assert str =~ "- https://example.com/api"
    end

    test "excludes optional fields when nil" do
      {:ok, msg} = SIWEMessage.new(@valid_attrs)
      str = SIWEMessage.to_string(msg)

      refute str =~ "Expiration Time:"
      refute str =~ "Not Before:"
      refute str =~ "Request ID:"
      refute str =~ "Resources:"
    end
  end

  describe "parse/1" do
    test "round-trips a SIWE message" do
      {:ok, original} = SIWEMessage.new(@valid_attrs)
      str = SIWEMessage.to_string(original)
      {:ok, parsed} = SIWEMessage.parse(str)

      assert parsed.domain == original.domain
      assert parsed.address == original.address
      assert parsed.uri == original.uri
      assert parsed.version == original.version
      assert parsed.chain_id == original.chain_id
      assert parsed.nonce == original.nonce
    end

    test "parses a message with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          expiration_time: ~U[2024-01-02 00:00:00Z],
          not_before: ~U[2024-01-01 00:00:00Z],
          request_id: "req-123",
          resources: ["https://example.com/api", "ipfs://abc"]
        })

      {:ok, original} = SIWEMessage.new(attrs)
      str = SIWEMessage.to_string(original)
      {:ok, parsed} = SIWEMessage.parse(str)

      assert parsed.expiration_time == ~U[2024-01-02 00:00:00Z]
      assert parsed.not_before == ~U[2024-01-01 00:00:00Z]
      assert parsed.request_id == "req-123"
      assert parsed.resources == ["https://example.com/api", "ipfs://abc"]
    end

    test "returns error for invalid format" do
      assert {:error, _} = SIWEMessage.parse("not a SIWE message")
    end

    test "returns error for empty string" do
      assert {:error, _} = SIWEMessage.parse("")
    end
  end

  describe "validate/2" do
    test "validates a non-expired message" do
      {:ok, msg} =
        SIWEMessage.new(
          Map.put(@valid_attrs, :expiration_time, ~U[2099-01-01 00:00:00Z])
        )

      assert :ok = SIWEMessage.validate(msg)
    end

    test "rejects an expired message" do
      {:ok, msg} =
        SIWEMessage.new(
          Map.put(@valid_attrs, :expiration_time, ~U[2020-01-01 00:00:00Z])
        )

      assert {:error, "message has expired"} = SIWEMessage.validate(msg)
    end

    test "rejects a message that is not yet valid" do
      {:ok, msg} =
        SIWEMessage.new(
          Map.put(@valid_attrs, :not_before, ~U[2099-01-01 00:00:00Z])
        )

      assert {:error, "message is not yet valid"} = SIWEMessage.validate(msg)
    end

    test "validates with custom now time" do
      {:ok, msg} =
        SIWEMessage.new(
          Map.put(@valid_attrs, :expiration_time, ~U[2024-06-01 00:00:00Z])
        )

      assert :ok =
               SIWEMessage.validate(msg, now: ~U[2024-01-01 00:00:00Z])

      assert {:error, "message has expired"} =
               SIWEMessage.validate(msg, now: ~U[2024-07-01 00:00:00Z])
    end

    test "validates message without expiration or not_before" do
      {:ok, msg} = SIWEMessage.new(@valid_attrs)
      assert :ok = SIWEMessage.validate(msg)
    end
  end

  describe "generate_nonce/0" do
    test "generates a hex string of correct length" do
      nonce = SIWEMessage.generate_nonce()
      assert is_binary(nonce)
      assert byte_size(nonce) == 32
      assert Regex.match?(~r/^[0-9a-f]+$/, nonce)
    end

    test "generates unique nonces" do
      nonces = for _ <- 1..100, do: SIWEMessage.generate_nonce()
      assert length(Enum.uniq(nonces)) == 100
    end
  end
end
