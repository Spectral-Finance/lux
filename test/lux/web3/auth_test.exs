defmodule Lux.Web3.AuthTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth

  # ---------------------------------------------------------------------------
  # Nonce management
  # ---------------------------------------------------------------------------

  describe "nonce management" do
    setup do
      # Ensure ETS table exists for testing
      if :ets.whereis(:lux_auth_nonces) == :undefined do
        :ets.new(:lux_auth_nonces, [:set, :public, :named_table])
      end

      :ok
    end

    test "generate_nonce/0 returns a hex-encoded 64-character string" do
      nonce = Auth.generate_nonce()
      assert is_binary(nonce)
      assert String.length(nonce) == 64
      assert nonce =~ ~r/^[0-9a-f]+$/
    end

    test "generate_nonce/0 returns unique values" do
      nonces = for _ <- 1..100, do: Auth.generate_nonce()
      assert Enum.uniq(nonces) |> length() == 100
    end

    test "store_nonce/1 and consume_nonce/1 round-trip" do
      nonce = Auth.generate_nonce()
      assert Auth.store_nonce(nonce) == :ok
      assert Auth.consume_nonce(nonce) == :ok
    end

    test "consume_nonce/1 rejects unknown nonces" do
      assert Auth.consume_nonce("nonexistent") == {:error, "Nonce not found or already consumed"}
    end

    test "consume_nonce/1 consumes a nonce only once (replay protection)" do
      nonce = Auth.generate_nonce()
      Auth.store_nonce(nonce)
      assert Auth.consume_nonce(nonce) == :ok
      assert Auth.consume_nonce(nonce) == {:error, "Nonce not found or already consumed"}
    end
  end

  # ---------------------------------------------------------------------------
  # generate_challenge/2
  # ---------------------------------------------------------------------------

  describe "generate_challenge/2" do
    setup do
      # Ensure ETS table exists for testing
      if :ets.whereis(:lux_auth_nonces) == :undefined do
        :ets.new(:lux_auth_nonces, [:set, :public, :named_table])
      end

      :ok
    end

    test "returns {:ok, message, nonce} with default configuration" do
      address = "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B"
      assert {:ok, message, nonce} = Auth.generate_challenge(address)

      assert String.contains?(message, "localhost:4000 wants you to sign in")
      assert String.contains?(message, address)
      assert String.contains?(message, "URI: http://localhost:4000")
      assert String.contains?(message, "Version: 1")
      assert String.contains?(message, "Chain ID: 1")
      assert String.contains?(message, "Nonce: #{nonce}")
      assert String.contains?(message, "Issued At: ")
      assert is_binary(nonce)
      assert String.length(nonce) == 64
    end

    test "uses custom opts over defaults" do
      address = "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B"
      opts = [
        domain: "app.example.com",
        uri: "https://app.example.com/login",
        chain_id: 137,
        statement: "Custom sign-in message."
      ]

      assert {:ok, message, _nonce} = Auth.generate_challenge(address, opts)
      assert String.contains?(message, "app.example.com wants you to sign in")
      assert String.contains?(message, "URI: https://app.example.com/login")
      assert String.contains?(message, "Chain ID: 137")
      assert String.contains?(message, "Custom sign-in message.")
    end

    test "stores the generated nonce for replay protection" do
      address = "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B"
      assert {:ok, _message, nonce} = Auth.generate_challenge(address)
      assert Auth.consume_nonce(nonce) == :ok
    end

    test "accepts an explicit nonce" do
      address = "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B"
      fixed_nonce = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
      assert {:ok, message, ^fixed_nonce} = Auth.generate_challenge(address, nonce: fixed_nonce)
      assert String.contains?(message, "Nonce: #{fixed_nonce}")
    end
  end

  # ---------------------------------------------------------------------------
  # parse_siwe/1
  # ---------------------------------------------------------------------------

  describe "parse_siwe/1" do
    test "parses a valid SIWE message" do
      message =
        "localhost:4000 wants you to sign in with your Ethereum account:\n" <>
          "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B\n\n" <>
          "Sign in with Ethereum to the app.\n\n" <>
          "URI: http://localhost:4000\n" <>
          "Version: 1\n" <>
          "Chain ID: 1\n" <>
          "Nonce: abc123\n" <>
          "Issued At: 2025-06-05T12:00:00Z"

      assert {:ok, fields} = Auth.parse_siwe(message)
      assert fields.domain == "localhost:4000"
      assert fields.address == "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B"
      assert fields.statement == "Sign in with Ethereum to the app."
      assert fields.uri == "http://localhost:4000"
      assert fields.version == "1"
      assert fields.chain_id == 1
      assert fields.nonce == "abc123"
      assert fields.issued_at == "2025-06-05T12:00:00Z"
    end

    test "parses a SIWE message with optional fields" do
      message =
        "app.example.com wants you to sign in with your Ethereum account:\n" <>
          "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B\n\n" <>
          "My custom statement.\n\n" <>
          "URI: https://app.example.com\n" <>
          "Version: 1\n" <>
          "Chain ID: 137\n" <>
          "Nonce: xyz789\n" <>
          "Issued At: 2025-06-05T12:00:00Z\n" <>
          "Expiration Time: 2025-06-05T13:00:00Z\n" <>
          "Not Before: 2025-06-05T11:00:00Z\n" <>
          "Request ID: req-001\n" <>
          "Resources:\n" <>
          "https://example.com/resource1\n" <>
          "https://example.com/resource2"

      assert {:ok, fields} = Auth.parse_siwe(message)
      assert fields.domain == "app.example.com"
      assert fields.chain_id == 137
      assert fields.expiration_time == "2025-06-05T13:00:00Z"
      assert fields.not_before == "2025-06-05T11:00:00Z"
      assert fields.request_id == "req-001"
      assert fields.resources == ["https://example.com/resource1", "https://example.com/resource2"]
    end

    test "returns error for empty message" do
      assert Auth.parse_siwe("") == {:error, "Empty message"}
    end

    test "returns error for malformed header" do
      assert Auth.parse_siwe("invalid message") == {:error, "Missing SIWE header"}
    end

    test "returns error for missing URI" do
      message =
        "localhost:4000 wants you to sign in with your Ethereum account:\n" <>
          "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B\n\n" <>
          "Version: 1\n" <>
          "Chain ID: 1\n" <>
          "Nonce: abc\n" <>
          "Issued At: 2025-06-05T12:00:00Z"

      assert Auth.parse_siwe(message) == {:error, "Missing URI field"}
    end

    test "parses SIWE message with no statement" do
      message =
        "localhost:4000 wants you to sign in with your Ethereum account:\n" <>
          "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B\n\n" <>
          "URI: http://localhost:4000\n" <>
          "Version: 1\n" <>
          "Chain ID: 1\n" <>
          "Nonce: abc\n" <>
          "Issued At: 2025-06-05T12:00:00Z"

      assert {:ok, fields} = Auth.parse_siwe(message)
      assert fields.statement == nil
    end
  end

  # ---------------------------------------------------------------------------
  # validate_siwe_fields/2
  # ---------------------------------------------------------------------------

  describe "validate_siwe_fields/2" do
    test "accepts valid fields" do
      fields = %{
        domain: "localhost:4000",
        address: "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B",
        statement: "Sign in with Ethereum to the app.",
        uri: "http://localhost:4000",
        version: "1",
        chain_id: 1,
        nonce: "abc123",
        issued_at: "2025-06-05T12:00:00Z"
      }

      assert Auth.validate_siwe_fields(fields) == :ok
    end

    test "rejects domain mismatch" do
      fields = %{
        domain: "wrong.com",
        address: "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B",
        statement: nil,
        uri: "http://localhost:4000",
        version: "1",
        chain_id: 1,
        nonce: "abc123",
        issued_at: "2025-06-05T12:00:00Z"
      }

      assert {:error, msg} = Auth.validate_siwe_fields(fields)
      assert msg =~ "Domain mismatch"
    end

    test "rejects URI mismatch" do
      fields = %{
        domain: "localhost:4000",
        address: "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B",
        statement: nil,
        uri: "https://evil.com",
        version: "1",
        chain_id: 1,
        nonce: "abc123",
        issued_at: "2025-06-05T12:00:00Z"
      }

      assert {:error, msg} = Auth.validate_siwe_fields(fields)
      assert msg =~ "URI mismatch"
    end

    test "rejects chain ID mismatch" do
      fields = %{
        domain: "localhost:4000",
        address: "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B",
        statement: nil,
        uri: "http://localhost:4000",
        version: "1",
        chain_id: 137,
        nonce: "abc123",
        issued_at: "2025-06-05T12:00:00Z"
      }

      assert Auth.validate_siwe_fields(fields) == {:error, "Chain ID mismatch"}
    end

    test "rejects expired message" do
      fields = %{
        domain: "localhost:4000",
        address: "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B",
        statement: nil,
        uri: "http://localhost:4000",
        version: "1",
        chain_id: 1,
        nonce: "abc123",
        issued_at: "2025-06-05T12:00:00Z",
        expiration_time: "2020-01-01T00:00:00Z"
      }

      assert Auth.validate_siwe_fields(fields) == {:error, "Message has expired"}
    end

    test "rejects future Not Before" do
      fields = %{
        domain: "localhost:4000",
        address: "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B",
        statement: nil,
        uri: "http://localhost:4000",
        version: "1",
        chain_id: 1,
        nonce: "abc123",
        issued_at: "2025-06-05T12:00:00Z",
        not_before: "2999-01-01T00:00:00Z"
      }

      assert Auth.validate_siwe_fields(fields) == {:error, "Not Before is in the future"}
    end
  end

  # ---------------------------------------------------------------------------
  # verify_signature/3
  # ---------------------------------------------------------------------------

  describe "verify_signature/3" do
    test "returns error for an invalid signature" do
      # A deliberately malformed signature
      assert Auth.verify_signature("hello", "0xbad", "0x0000000000000000000000000000000000000000") ==
               {:error, _msg}
    end

    test "returns error for empty signature" do
      assert Auth.verify_signature("hello", "", "0x0000000000000000000000000000000000000000") ==
               {:error, _msg}
    end
  end

  # ---------------------------------------------------------------------------
  # verify_siwe/4 (full flow — integration-level)
  # ---------------------------------------------------------------------------

  describe "verify_siwe/4" do
    setup do
      if :ets.whereis(:lux_auth_nonces) == :undefined do
        :ets.new(:lux_auth_nonces, [:set, :public, :named_table])
      end

      :ok
    end

    test "returns error for invalid SIWE message format" do
      assert Auth.verify_siwe("garbage", "0xsig", "0xaddr") == {:error, "Missing SIWE header"}
    end

    test "returns error for nonce not found (replay or unknown nonce)" do
      message =
        "localhost:4000 wants you to sign in with your Ethereum account:\n" <>
          "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B\n\n" <>
          "URI: http://localhost:4000\n" <>
          "Version: 1\n" <>
          "Chain ID: 1\n" <>
          "Nonce: nonexistentnonce\n" <>
          "Issued At: 2025-06-05T12:00:00Z"

      assert Auth.verify_siwe(message, "0xsig", "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B") ==
               {:error, "Nonce not found or already consumed"}
    end

    test "returns error for domain mismatch" do
      nonce = Auth.generate_nonce()
      Auth.store_nonce(nonce)

      message =
        "evil.com wants you to sign in with your Ethereum account:\n" <>
          "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B\n\n" <>
          "URI: http://localhost:4000\n" <>
          "Version: 1\n" <>
          "Chain ID: 1\n" <>
          "Nonce: #{nonce}\n" <>
          "Issued At: 2025-06-05T12:00:00Z"

      assert Auth.verify_siwe(message, "0xsig", "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B") ==
               {:error, _msg}
    end
  end

  # ---------------------------------------------------------------------------
  # EIP-1271
  # ---------------------------------------------------------------------------

  describe "verify_eip1271/4" do
    test "returns error when no RPC is available" do
      result = Auth.verify_eip1271("hello", "0xsig", "0x0000000000000000000000000000000000000001")

      assert result == {:error, _msg}
    end
  end

  # ---------------------------------------------------------------------------
  # authorize/3
  # ---------------------------------------------------------------------------

  describe "authorize/3" do
    test "allows access when user has a matching role (flat list)" do
      assert Auth.authorize(:read, [:admin, :editor], [:admin, :editor]) == {:ok, :authorized}
      assert Auth.authorize(:read, [:viewer], [:viewer, :guest]) == {:ok, :authorized}
    end

    test "denies access when user has no matching role (flat list)" do
      assert Auth.authorize(:read, [:viewer], [:admin, :editor]) == {:error, :forbidden}
    end

    test "allows access for action-specific roles" do
      rules = [
        read: [:viewer, :editor, :admin],
        write: [:editor, :admin],
        admin: [:admin]
      ]

      assert Auth.authorize(:read, [:viewer], rules) == {:ok, :authorized}
      assert Auth.authorize(:write, [:editor], rules) == {:ok, :authorized}
      assert Auth.authorize(:admin, [:admin], rules) == {:ok, :authorized}
    end

    test "denies access when action has no rule and required_roles is a keyword list" do
      rules = [read: [:viewer], write: [:editor]]
      assert Auth.authorize(:delete, [:admin], rules) == {:error, :forbidden}
    end

    test "denies access for action-specific roles when user lacks the right role" do
      rules = [read: [:viewer, :editor], write: [:editor, :admin]]
      assert Auth.authorize(:write, [:viewer], rules) == {:error, :forbidden}
    end

    test "action parameter is used for authorization decisions" do
      rules = [
        read: [:viewer],
        write: [:editor]
      ]

      # viewer can read but not write
      assert Auth.authorize(:read, [:viewer], rules) == {:ok, :authorized}
      assert Auth.authorize(:write, [:viewer], rules) == {:error, :forbidden}

      # editor can write but that doesn't give viewer write access
      assert Auth.authorize(:write, [:editor], rules) == {:ok, :authorized}
    end

    test "empty user roles is always denied" do
      assert Auth.authorize(:read, [], [:admin]) == {:error, :forbidden}
      assert Auth.authorize(:read, [], [read: [:admin]]) == {:error, :forbidden}
    end
  end
end
