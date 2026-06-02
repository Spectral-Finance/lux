defmodule Lux.Web3.Auth.SIWE.Test do
  use ExUnit.Case, async: true
  @moduletag :unit

  alias Lux.Web3.Auth.SIWE

  describe "build_message/1" do
    test "builds a basic SIWE message" do
      siwe = %SIWE{
        domain: "lux.spectral.finance",
        address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        statement: "Sign in to Lux DeFi platform",
        uri: "https://lux.spectral.finance",
        version: "1",
        chain_id: 1,
        nonce: "abc123def456",
        issued_at: "2024-01-01T00:00:00Z",
        expiration_time: "2024-01-02T00:00:00Z",
        resources: ["https://lux.spectral.finance/trading", "https://lux.spectral.finance/yield"]
      }

      message = SIWE.build_message(siwe)

      assert message =~ "lux.spectral.finance wants you to sign in with your Ethereum account:"
      assert message =~ "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
      assert message =~ "Sign in to Lux DeFi platform"
      assert message =~ "URI: https://lux.spectral.finance"
      assert message =~ "Version: 1"
      assert message =~ "Chain ID: 1"
      assert message =~ "Nonce: abc123def456"
      assert message =~ "Issued At: 2024-01-01T00:00:00Z"
      assert message =~ "Expiration Time: 2024-01-02T00:00:00Z"
      assert message =~ "Resources:"
      assert message =~ "- https://lux.spectral.finance/trading"
      assert message =~ "- https://lux.spectral.finance/yield"
    end

    test "builds a minimal SIWE message without optional fields" do
      siwe = %SIWE{
        domain: "app.example.com",
        address: "0x1234567890abcdef1234567890abcdef12345678",
        uri: "https://app.example.com",
        version: "1",
        chain_id: 137,
        nonce: "minimal_nonce",
        issued_at: "2024-06-15T12:00:00Z",
        statement: nil,
        expiration_time: nil,
        not_before: nil,
        request_id: nil,
        resources: []
      }

      message = SIWE.build_message(siwe)

      assert message =~ "URI: https://app.example.com"
      assert message =~ "Chain ID: 137"
      refute message =~ "Statement:"
      refute message =~ "Expiration Time:"
      refute message =~ "Not Before:"
      refute message =~ "Resources:"
    end
  end

  describe "parse_message/1" do
    test "parses a valid SIWE message" do
      message = """
      app.example.com wants you to sign in with your Ethereum account:
      0x1234567890abcdef1234567890abcdef12345678

      URI: https://app.example.com
      Version: 1
      Chain ID: 137
      Nonce: test_nonce_123
      Issued At: 2024-06-15T12:00:00Z
      """

      assert {:ok, siwe} = SIWE.parse_message(message)
      assert siwe.domain == "app.example.com"
      assert siwe.chain_id == 137
      assert siwe.nonce == "test_nonce_123"
    end
  end

  describe "generate_nonce/0" do
    test "generates a hex nonce" do
      nonce = SIWE.generate_nonce()
      assert is_binary(nonce)
      assert byte_size(nonce) == 64
      assert nonce =~ ~r/^[0-9a-f]+$/
    end

    test "generates nonces of configurable length" do
      nonce = SIWE.generate_nonce(16)
      assert byte_size(nonce) == 32
    end
  end

  describe "validate/1" do
    test "validates a correct SIWE message" do
      siwe = %SIWE{
        domain: "example.com",
        address: "0x1234567890abcdef1234567890abcdef12345678",
        uri: "https://example.com",
        version: "1",
        chain_id: 1,
        nonce: "abc123",
        issued_at: "2024-01-01T00:00:00Z"
      }

      assert :ok = SIWE.validate(siwe)
    end

    test "rejects SIWE with empty domain" do
      siwe = %SIWE{domain: "", address: "0x1234567890abcdef1234567890abcdef12345678",
                    uri: "https://example.com", version: "1", chain_id: 1,
                    nonce: "abc", issued_at: "2024-01-01T00:00:00Z"}

      assert {:error, "Domain is required"} = SIWE.validate(siwe)
    end

    test "rejects invalid Ethereum address" do
      siwe = %SIWE{domain: "example.com", address: "invalid",
                    uri: "https://example.com", version: "1", chain_id: 1,
                    nonce: "abc", issued_at: "2024-01-01T00:00:00Z"}

      assert {:error, _} = SIWE.validate(siwe)
    end
  end

  describe "expired?/1" do
    test "returns false for future expiration" do
      future = DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.to_iso8601()
      siwe = %SIWE{domain: "a", address: "0x1234567890abcdef1234567890abcdef12345678",
                    uri: "https://a", version: "1", chain_id: 1,
                    nonce: "a", issued_at: "2024-01-01T00:00:00Z",
                    expiration_time: future}

      refute SIWE.expired?(siwe)
    end

    test "returns true for past expiration" do
      past = "2020-01-01T00:00:00Z"
      siwe = %SIWE{domain: "a", address: "0x1234567890abcdef1234567890abcdef12345678",
                    uri: "https://a", version: "1", chain_id: 1,
                    nonce: "a", issued_at: "2020-01-01T00:00:00Z",
                    expiration_time: past}

      assert SIWE.expired?(siwe)
    end

    test "returns false when no expiration set" do
      siwe = %SIWE{domain: "a", address: "0x1234567890abcdef1234567890abcdef12345678",
                    uri: "https://a", version: "1", chain_id: 1,
                    nonce: "a", issued_at: "2024-01-01T00:00:00Z",
                    expiration_time: nil}

      refute SIWE.expired?(siwe)
    end
  end
end
