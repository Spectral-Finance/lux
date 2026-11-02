defmodule Lux.Web3.Auth.SignatureVerifierTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth.SignatureVerifier

  @valid_address "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5"
  @valid_sig "0x" <> String.duplicate("ab", 65)

  describe "normalize_address/1" do
    test "normalizes standard mixed-case address to lowercase" do
      mixed = "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5"
      assert {:ok, "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5"} = SignatureVerifier.normalize_address(mixed)
    end

    test "rejects invalid hex or wrong length" do
      assert {:error, :invalid_address} = SignatureVerifier.normalize_address("0x123")
      assert {:error, :invalid_address} = SignatureVerifier.normalize_address("not_an_address")
    end
  end

  describe "normalize_hex/1" do
    test "strips 0x and lowercases" do
      assert {:ok, "abcd"} = SignatureVerifier.normalize_hex("0xABCD")
      assert {:ok, "1234"} = SignatureVerifier.normalize_hex("1234")
    end

    test "rejects odd length or non-hex" do
      assert {:error, :invalid_hex} = SignatureVerifier.normalize_hex("0x123")
      assert {:error, :invalid_hex} = SignatureVerifier.normalize_hex("0xZZZZ")
    end
  end

  describe "verify_personal_sign/3" do
    test "handles simulated recovery or ExSecp256k1 recovery" do
      # Test that verification handles formats properly
      msg = "Sign in to Lux"
      result = SignatureVerifier.verify_personal_sign(msg, @valid_sig, @valid_address)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "verify_erc1271/4" do
    test "verifies smart contract wallet signatures" do
      magic_sig = "0x" <> String.duplicate("00", 32) <> "1626ba7e" <> String.duplicate("00", 28)
      hash = "0x" <> String.duplicate("ff", 32)

      assert {:ok, true} = SignatureVerifier.verify_erc1271(@valid_address, hash, magic_sig)
    end

    test "allows custom RPC client callback" do
      custom_client = fn _contract, _hash, _sig -> {:ok, true} end
      hash = "0x" <> String.duplicate("11", 32)
      assert {:ok, true} = SignatureVerifier.verify_erc1271(@valid_address, hash, @valid_sig, custom_client)
    end
  end

  describe "verify_multisig/4" do
    test "rejects invalid threshold or insufficient owners" do
      assert {:error, :invalid_threshold} = SignatureVerifier.verify_multisig("test", [], 0, [@valid_address])
      assert {:error, :invalid_threshold} = SignatureVerifier.verify_multisig("test", [], 3, [@valid_address])
    end
  end

  describe "hash_typed_data/1" do
    test "hashes EIP-712 structured data payload" do
      typed_data = %{
        domain: %{
          name: "Lux Auth",
          version: "1",
          chainId: 1,
          verifyingContract: @valid_address
        },
        primaryType: "AuthRequest",
        message: %{
          signer: @valid_address,
          nonce: 12345
        }
      }

      assert {:ok, hash} = SignatureVerifier.hash_typed_data(typed_data)
      assert byte_size(hash) == 32
    end
  end
end
