defmodule Lux.Web3.Auth.SIWETest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth.SIWE

  @valid_address "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5"

  describe "generate_nonce/1" do
    test "generates random alphanumeric string of expected length" do
      nonce1 = SIWE.generate_nonce(16)
      nonce2 = SIWE.generate_nonce(16)

      assert String.length(nonce1) == 16
      assert String.length(nonce2) == 16
      assert nonce1 != nonce2
      assert Regex.match?(~r/^[a-zA-Z0-9]+$/, nonce1)
    end

    test "respects minimum 8 character nonce requirement" do
      nonce = SIWE.generate_nonce(8)
      assert String.length(nonce) == 8
    end
  end

  describe "format_message/1 and parse_message/1" do
    test "formats a complete EIP-4361 message and roundtrips with parse_message" do
      params = %{
        domain: "app.lux.network",
        address: @valid_address,
        statement: "Sign in with Ethereum to the Lux AI Agent network.",
        uri: "https://app.lux.network/login",
        version: "1",
        chain_id: 1,
        nonce: "B3x9aK01Lzq92mOP",
        issued_at: "2026-11-02T12:00:00Z",
        expiration_time: "2026-11-02T12:30:00Z",
        not_before: "2026-11-02T11:59:00Z",
        request_id: "req_9921",
        resources: [
          "urn:lux:access:agent_runner",
          "urn:lux:access:vault"
        ]
      }

      assert {:ok, formatted} = SIWE.format_message(params)
      assert String.contains?(formatted, "app.lux.network wants you to sign in with your Ethereum account:")
      assert String.contains?(formatted, @valid_address)
      assert String.contains?(formatted, "URI: https://app.lux.network/login")
      assert String.contains?(formatted, "Nonce: B3x9aK01Lzq92mOP")
      assert String.contains?(formatted, "Resources:\n- urn:lux:access:agent_runner\n- urn:lux:access:vault")

      assert {:ok, parsed} = SIWE.parse_message(formatted)
      assert parsed.domain == "app.lux.network"
      assert parsed.address == @valid_address
      assert parsed.statement == "Sign in with Ethereum to the Lux AI Agent network."
      assert parsed.uri == "https://app.lux.network/login"
      assert parsed.chain_id == 1
      assert parsed.nonce == "B3x9aK01Lzq92mOP"
      assert parsed.resources == ["urn:lux:access:agent_runner", "urn:lux:access:vault"]
    end

    test "returns error on missing required fields" do
      assert {:error, :missing_domain} = SIWE.format_message(%{address: @valid_address, uri: "https://foo", nonce: "123", issued_at: "2026"})
      assert {:error, :missing_address} = SIWE.format_message(%{domain: "test.com", uri: "https://foo", nonce: "123", issued_at: "2026"})
    end
  end

  describe "validate/2" do
    test "validates matching nonce and domain" do
      msg = %{
        domain: "lux.network",
        address: @valid_address,
        nonce: "nonce123",
        chain_id: 1,
        expiration_time: nil,
        not_before: nil
      }

      assert :ok = SIWE.validate(msg, expected_domain: "lux.network", expected_nonce: "nonce123")
      assert {:error, :nonce_mismatch} = SIWE.validate(msg, expected_nonce: "diff_nonce")
      assert {:error, :domain_mismatch} = SIWE.validate(msg, expected_domain: "evil.com")
    end

    test "validates expiration time correctly" do
      now = ~U[2026-11-02 12:00:00Z]

      unexpired = %{
        domain: "lux.network",
        nonce: "n",
        chain_id: 1,
        expiration_time: "2026-11-02T12:15:00Z",
        not_before: nil
      }
      assert :ok = SIWE.validate(unexpired, as_of: now)

      expired = %{
        domain: "lux.network",
        nonce: "n",
        chain_id: 1,
        expiration_time: "2026-11-02T11:45:00Z",
        not_before: nil
      }
      assert {:error, :message_expired} = SIWE.validate(expired, as_of: now)
    end
  end
end
