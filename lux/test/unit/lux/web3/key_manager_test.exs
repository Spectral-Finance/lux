defmodule Lux.Web3.KeyManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.KeyManager

  describe "encrypt/1 and decrypt/1" do
    test "successfully encrypts and decrypts a private key string" do
      plaintext = "0x0000000000000000000000000000000000000000000000000000000000000001"

      assert {:ok, encrypted} = KeyManager.encrypt(plaintext)
      assert is_binary(encrypted)
      # Ensure it is a valid base64url encoded string (alphanumeric, -, _, no padding or trailing =)
      assert match?({:ok, _}, Base.url_decode64(encrypted))

      # Decrypt and verify
      assert {:ok, decrypted} = KeyManager.decrypt(encrypted)
      assert decrypted == plaintext
    end

    test "handles decryption of invalid payloads" do
      assert {:error, "Invalid encrypted payload format"} = KeyManager.decrypt("notbase64!!!")
      assert {:error, "Invalid encrypted payload format"} = KeyManager.decrypt("AAAA") # Too short
    end

    test "handles decryption with corrupted data or invalid tag" do
      plaintext = "my_secret_key"
      {:ok, encrypted} = KeyManager.encrypt(plaintext)
      
      # Modify one character of the base64 string to simulate corruption
      <<first::binary-size(5), rest::binary>> = encrypted
      corrupted = first <> "X" <> String.slice(rest, 1..-1//1)

      case KeyManager.decrypt(corrupted) do
        {:error, _reason} -> :ok
        {:ok, decrypted} -> flunk("Expected decryption to fail but got: #{decrypted}")
      end
    end

    test "different encryptions of same plaintext produce different ciphertexts due to random IV" do
      plaintext = "test_key"
      assert {:ok, enc1} = KeyManager.encrypt(plaintext)
      assert {:ok, enc2} = KeyManager.encrypt(plaintext)
      
      refute enc1 == enc2
      
      assert {:ok, dec1} = KeyManager.decrypt(enc1)
      assert {:ok, dec2} = KeyManager.decrypt(enc2)
      
      assert dec1 == plaintext
      assert dec2 == plaintext
    end
  end
end
