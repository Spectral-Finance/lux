defmodule Lux.Web3.SignatureTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Signature.Verifier

  describe "hash_personal_message/1" do
    test "produces a 32-byte keccak-256 hash" do
      message = "Hello, World!"
      hashed = Verifier.hash_personal_message(message)
      assert byte_size(hashed) == 32
    end

    test "is deterministic" do
      message = "same message"
      assert Verifier.hash_personal_message(message) == Verifier.hash_personal_message(message)
    end
  end

  describe "hash_typed_data/1" do
    test "produces a 32-byte hash" do
      data = <<0::256>>
      hashed = Verifier.hash_typed_data(data)
      assert byte_size(hashed) == 32
    end
  end

  describe "verify_signature/3" do
    test "returns false for mismatched address" do
      message = "test message"
      # Use an invalid signature - should not match any address
      signature = :crypto.strong_rand_bytes(65)
      refute Verifier.verify_signature("0x0000000000000000000000000000000000000001", message, signature)
    end
  end

  describe "recover_address/2" do
    test "returns error for invalid signature length" do
      message = "test"
      short_sig = <<1, 2, 3>>
      assert {:error, :invalid_signature_length} = Verifier.recover_address(message, short_sig)
    end
  end

  describe "verify_multisig/3" do
    test "requires minimum threshold signatures" do
      message = "multisig message"

      # Create fake signatures
      sig_pairs = [
        {:crypto.strong_rand_bytes(65), %{}},
        {:crypto.strong_rand_bytes(65), %{}}
      ]

      assert {:error, reason} = Verifier.verify_multisig(message, sig_pairs, 2)
      assert reason =~ "Insufficient signatures"
    end
  end
end
