defmodule Lux.Web3.WalletInfrastructure.KeyManagerTest do
  use UnitCase, async: true

  alias Lux.Web3.WalletInfrastructure.KeyManager

  describe "generate_mnemonic/1 and derive_hd_account/2" do
    test "generates 12-word mnemonic and derives BIP-44 child accounts" do
      mnemonic = KeyManager.generate_mnemonic(12)
      words = String.split(mnemonic, " ")
      assert length(words) == 12

      account0 = KeyManager.derive_hd_account(mnemonic, 0)
      account1 = KeyManager.derive_hd_account(mnemonic, 1)

      assert String.starts_with?(account0.address, "0x")
      assert String.length(account0.address) == 42
      assert account0.path == "m/44'/60'/0'/0/0"
      assert account1.path == "m/44'/60'/0'/0/1"
      refute account0.address == account1.address
    end
  end

  describe "valid_private_key?/1 and private_key_to_address/1" do
    test "validates hex private key length and formatting" do
      valid_key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      assert KeyManager.valid_private_key?(valid_key) == true
      assert KeyManager.valid_private_key?("0x" <> valid_key) == true
      assert KeyManager.valid_private_key?("invalid_short_key") == false

      address = KeyManager.private_key_to_address(valid_key)
      assert String.starts_with?(address, "0x")
      assert String.length(address) == 42
    end
  end

  describe "encrypt_key/2 and decrypt_key/2" do
    test "encrypts and decrypts sensitive key material using AES-256-GCM" do
      secret = "abandon ability able about above absent absorb abstract absurd abuse access accident"
      passphrase = "my_ultra_secure_password"

      encrypted = KeyManager.encrypt_key(secret, passphrase)

      assert encrypted.algorithm == "AES-256-GCM"
      assert is_binary(encrypted.ciphertext_hex)
      assert is_binary(encrypted.iv_hex)
      assert is_binary(encrypted.tag_hex)

      # Decrypt with correct passphrase
      assert {:ok, ^secret} = KeyManager.decrypt_key(encrypted, passphrase)

      # Decrypt with wrong passphrase fails
      assert {:error, :decryption_failed} = KeyManager.decrypt_key(encrypted, "wrong_pass")
    end
  end
end
