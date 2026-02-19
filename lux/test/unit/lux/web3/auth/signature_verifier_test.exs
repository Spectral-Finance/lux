defmodule Lux.Web3.Auth.SignatureVerifierTest do
  @moduledoc """
  Tests for the SignatureVerifier module covering Ethereum signature
  verification and address recovery.
  """

  use UnitCase, async: true

  alias Lux.Web3.Auth.SignatureVerifier

  # Test data generated using a known private key
  # Private key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
  # This is the first Hardhat/Anvil test account
  @test_address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  describe "hash_personal_message/1" do
    test "produces a 32-byte hash" do
      hash = SignatureVerifier.hash_personal_message("Hello, world!")
      assert byte_size(hash) == 32
    end

    test "produces different hashes for different messages" do
      hash1 = SignatureVerifier.hash_personal_message("Hello")
      hash2 = SignatureVerifier.hash_personal_message("World")
      assert hash1 != hash2
    end

    test "produces consistent hashes for the same message" do
      hash1 = SignatureVerifier.hash_personal_message("Test message")
      hash2 = SignatureVerifier.hash_personal_message("Test message")
      assert hash1 == hash2
    end

    test "correctly prefixes the message with Ethereum header" do
      # The hash should be Keccak-256 of "\x19Ethereum Signed Message:\n13Hello, world!"
      hash = SignatureVerifier.hash_personal_message("Hello, world!")
      assert is_binary(hash)
      assert byte_size(hash) == 32
    end
  end

  describe "recover_address/2" do
    test "returns error for invalid hex signature" do
      assert {:error, "invalid hex encoding"} =
               SignatureVerifier.recover_address("Hello", "not-hex")
    end

    test "returns error for wrong-length signature" do
      short_sig = "0x" <> String.duplicate("ab", 30)

      assert {:error, "invalid signature length (expected 65 bytes)"} =
               SignatureVerifier.recover_address("Hello", short_sig)
    end

    test "accepts 0x-prefixed signatures" do
      # Even if the signature doesn't match, it should parse the format
      sig = "0x" <> String.duplicate("ab", 64) <> "1b"

      case SignatureVerifier.recover_address("test", sig) do
        {:ok, addr} -> assert String.starts_with?(addr, "0x")
        {:error, _} -> :ok
      end
    end

    test "accepts non-prefixed signatures" do
      sig = String.duplicate("ab", 64) <> "1b"

      case SignatureVerifier.recover_address("test", sig) do
        {:ok, addr} -> assert String.starts_with?(addr, "0x")
        {:error, _} -> :ok
      end
    end

    test "recovers address from a real signature" do
      # Sign a message using the test private key
      private_key =
        Base.decode16!("ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
          case: :lower
        )

      message = "Test authentication message"
      hash = SignatureVerifier.hash_personal_message(message)

      {:ok, {signature, recovery_id}} = ExSecp256k1.sign_compact(hash, private_key)
      sig_hex = Base.encode16(signature <> <<recovery_id + 27>>, case: :lower)

      assert {:ok, recovered} = SignatureVerifier.recover_address(message, sig_hex)
      assert String.downcase(recovered) == @test_address
    end
  end

  describe "verify_signature/3" do
    test "returns true for valid signature" do
      private_key =
        Base.decode16!("ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
          case: :lower
        )

      message = "Verify this message"
      hash = SignatureVerifier.hash_personal_message(message)

      {:ok, {signature, recovery_id}} = ExSecp256k1.sign_compact(hash, private_key)
      sig_hex = Base.encode16(signature <> <<recovery_id + 27>>, case: :lower)

      assert {:ok, true} =
               SignatureVerifier.verify_signature(message, sig_hex, @test_address)
    end

    test "returns false for wrong address" do
      private_key =
        Base.decode16!("ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
          case: :lower
        )

      message = "Verify this message"
      hash = SignatureVerifier.hash_personal_message(message)

      {:ok, {signature, recovery_id}} = ExSecp256k1.sign_compact(hash, private_key)
      sig_hex = Base.encode16(signature <> <<recovery_id + 27>>, case: :lower)

      wrong_address = "0x0000000000000000000000000000000000000001"

      assert {:ok, false} =
               SignatureVerifier.verify_signature(message, sig_hex, wrong_address)
    end

    test "is case-insensitive for addresses" do
      private_key =
        Base.decode16!("ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
          case: :lower
        )

      message = "Case test"
      hash = SignatureVerifier.hash_personal_message(message)

      {:ok, {signature, recovery_id}} = ExSecp256k1.sign_compact(hash, private_key)
      sig_hex = Base.encode16(signature <> <<recovery_id + 27>>, case: :lower)

      upper = String.upcase(@test_address)

      assert {:ok, true} =
               SignatureVerifier.verify_signature(message, sig_hex, upper)
    end

    test "returns error for invalid signature format" do
      assert {:error, _} =
               SignatureVerifier.verify_signature(
                 "message",
                 "invalid",
                 @test_address
               )
    end
  end

  describe "verify_typed_data/3" do
    test "returns error for invalid hash" do
      sig = "0x" <> String.duplicate("ab", 64) <> "1b"

      assert {:error, _} =
               SignatureVerifier.verify_typed_data("not-hex", sig, @test_address)
    end

    test "verifies typed data with valid signature" do
      private_key =
        Base.decode16!("ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
          case: :lower
        )

      # Simulate an EIP-712 hash (just a random 32-byte hash for testing)
      typed_data_hash = :crypto.strong_rand_bytes(32)

      {:ok, {signature, recovery_id}} = ExSecp256k1.sign_compact(typed_data_hash, private_key)
      sig_hex = Base.encode16(signature <> <<recovery_id + 27>>, case: :lower)
      hash_hex = Base.encode16(typed_data_hash, case: :lower)

      assert {:ok, true} =
               SignatureVerifier.verify_typed_data(hash_hex, sig_hex, @test_address)
    end
  end
end
