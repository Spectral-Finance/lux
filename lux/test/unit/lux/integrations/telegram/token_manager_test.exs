defmodule Lux.Integrations.Telegram.TokenManagerTest do
  # Not async: these tests mutate global application config / system env.
  use ExUnit.Case, async: false

  alias Lux.Integrations.Telegram.TokenManager

  # Snapshot and restore global config/env around each test so the suite is
  # deterministic regardless of the host machine's TELEGRAM_BOT_TOKEN.
  setup do
    original_api_keys = Application.get_env(:lux, :api_keys)
    original_env = System.get_env("TELEGRAM_BOT_TOKEN")

    on_exit(fn ->
      restore_api_keys(original_api_keys)
      restore_env(original_env)
    end)

    :ok
  end

  describe "resolve_token/1" do
    test "returns token from explicit option" do
      token = "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
      assert {:ok, ^token} = TokenManager.resolve_token(token: token)
    end

    test "returns error when no token configured" do
      # Ensure no config/env is visible to the resolver.
      System.delete_env("TELEGRAM_BOT_TOKEN")
      Application.delete_env(:lux, :api_keys)
      assert {:error, :token_not_configured} = TokenManager.resolve_token([])
    end

    test "returns error for empty token" do
      assert {:error, :token_not_configured} = TokenManager.resolve_token(token: "")
    end

    test "returns error for invalid token format" do
      assert {:error, :invalid_token_format} = TokenManager.resolve_token(token: "invalid")
    end

    test "resolves from environment variable" do
      token = "789012:XYZ-ABC1234defGHI5678jkl"
      Application.delete_env(:lux, :api_keys)
      System.put_env("TELEGRAM_BOT_TOKEN", token)

      assert {:ok, ^token} = TokenManager.resolve_token([])
    end
  end

  describe "resolve_token!/1" do
    test "returns token on success" do
      token = "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
      assert ^token = TokenManager.resolve_token!(token: token)
    end

    test "raises on error" do
      assert_raise RuntimeError, ~r/token error/, fn ->
        TokenManager.resolve_token!(token: "invalid")
      end
    end
  end

  describe "validate_token/1" do
    test "accepts valid token format" do
      token = "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
      assert {:ok, ^token} = TokenManager.validate_token(token)
    end

    test "rejects token without colon" do
      assert {:error, :invalid_token_format} = TokenManager.validate_token("invalidtoken")
    end

    test "rejects token with non-numeric bot_id" do
      assert {:error, :invalid_token_format} = TokenManager.validate_token("abc:SECRET123456789")
    end

    test "rejects token with empty secret" do
      assert {:error, :invalid_token_format} = TokenManager.validate_token("123456:")
    end

    test "rejects token with short secret" do
      assert {:error, :invalid_token_format} = TokenManager.validate_token("123456:short")
    end

    test "rejects non-binary input" do
      assert {:error, :invalid_token_format} = TokenManager.validate_token(123)
      assert {:error, :invalid_token_format} = TokenManager.validate_token(nil)
    end
  end

  describe "valid_token_format?/1" do
    test "returns true for valid format" do
      assert TokenManager.valid_token_format?("123456:ABC-DEF1234ghIkl")
    end

    test "returns false for invalid format" do
      refute TokenManager.valid_token_format?("invalid")
      refute TokenManager.valid_token_format?("123456:")
      refute TokenManager.valid_token_format?("abc:SECRET123456789")
      refute TokenManager.valid_token_format?(nil)
    end
  end

  describe "mask_token/1" do
    test "masks long token" do
      token = "123456:ABC-DEF1234ghIkl"
      assert "1234...hIkl" = TokenManager.mask_token(token)
    end

    test "masks short token" do
      assert "***" = TokenManager.mask_token("short")
    end

    test "masks non-binary" do
      assert "***" = TokenManager.mask_token(nil)
    end
  end

  describe "constant_time_compare/2" do
    test "returns true for equal tokens" do
      assert TokenManager.constant_time_compare("abc123", "abc123")
    end

    test "returns false for different tokens" do
      refute TokenManager.constant_time_compare("abc123", "def456")
    end

    test "returns false for different lengths" do
      refute TokenManager.constant_time_compare("abc", "abcdef")
    end

    test "returns false for non-binary" do
      refute TokenManager.constant_time_compare(nil, "abc")
      refute TokenManager.constant_time_compare("abc", nil)
    end
  end

  # Helpers to restore global state after tests that mutate config/env.

  defp restore_api_keys(nil), do: Application.delete_env(:lux, :api_keys)
  defp restore_api_keys(value), do: Application.put_env(:lux, :api_keys, value)

  defp restore_env(nil), do: System.delete_env("TELEGRAM_BOT_TOKEN")
  defp restore_env(value), do: System.put_env("TELEGRAM_BOT_TOKEN", value)
end