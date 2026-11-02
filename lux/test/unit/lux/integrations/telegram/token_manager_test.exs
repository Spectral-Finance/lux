defmodule Lux.Integrations.Telegram.TokenManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.TokenManager

  describe "token format validation" do
    test "validates correct Telegram bot tokens" do
      assert TokenManager.valid_token_format?("123456789:ABCdefGHIjklMNOpqrSTUvwxYZ123456789")
      assert TokenManager.valid_token_format?("9876543210:aBcDeFgHiJkLmNoPqRsTuVwXyZ123456789")
    end

    test "rejects invalid tokens" do
      refute TokenManager.valid_token_format?("invalid_token")
      refute TokenManager.valid_token_format?("123:short")
      refute TokenManager.valid_token_format?("")
      refute TokenManager.valid_token_format?(nil)
    end
  end

  describe "extract_bot_id/1" do
    test "extracts numerical bot ID" do
      assert {:ok, 123_456_789} =
               TokenManager.extract_bot_id("123456789:ABCdefGHIjklMNOpqrSTUvwxYZ123456789")
    end

    test "returns error on invalid token format" do
      assert {:error, :invalid_token} = TokenManager.extract_bot_id("not_a_valid_token")
    end
  end

  describe "mask_token/1" do
    test "masks secret portion of token for logging" do
      masked = TokenManager.mask_token("123456789:ABCdefGHIjklMNOpqrSTUvwxYZ123456789")
      assert masked == "123456789:ABCd...6789"
    end

    test "returns placeholder on invalid token" do
      assert TokenManager.mask_token("short") == "***masked***"
    end
  end

  describe "token encryption and registry" do
    test "encrypts and decrypts bot token with AES-256-GCM" do
      token = "123456789:ABCdefGHIjklMNOpqrSTUvwxYZ123456789"
      passphrase = "super_secure_passphrase"

      encrypted = TokenManager.encrypt_token(token, passphrase)
      assert is_binary(encrypted)
      assert encrypted != token

      assert {:ok, ^token} = TokenManager.decrypt_token(encrypted, passphrase)
      assert {:error, :decryption_failed} = TokenManager.decrypt_token(encrypted, "wrong_pass")
    end

    test "registers and retrieves bot token from registry" do
      token = "123456789:ABCdefGHIjklMNOpqrSTUvwxYZ123456789"
      passphrase = "vault_passphrase"

      reg = TokenManager.init_registry()
      {:ok, reg1, record} = TokenManager.register_bot(reg, "primary_bot", token, passphrase)

      assert record.bot_id == 123_456_789
      assert record.name == "primary_bot"

      assert {:ok, ^token} = TokenManager.get_bot_token(reg1, "primary_bot", passphrase)
      assert {:error, :not_found} = TokenManager.get_bot_token(reg1, "unknown_bot", passphrase)
    end
  end
end
