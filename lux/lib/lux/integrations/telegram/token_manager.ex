defmodule Lux.Integrations.Telegram.TokenManager do
  @moduledoc """
  Secure token management for the Telegram Bot API.

  Handles token resolution from multiple sources (application config, runtime
  environment, explicit argument), token validation, and secure storage
  without exposing tokens in logs or error messages.

  ## Token Sources (in priority order)

  1. Explicit `token:` option passed to a function
  2. Application environment (`:lux, :api_keys, :telegram_bot`)
  3. Runtime environment variable (`TELEGRAM_BOT_TOKEN`)

  ## Security

  - Tokens are never logged or included in error messages
  - Tokens are validated for format before use
  - Token comparison uses constant-time comparison to prevent timing attacks
  """

  require Logger

  @type token :: String.t()

  @doc """
  Resolves the Telegram bot token from the given options or configuration.

  Returns `{:ok, token}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> TokenManager.resolve_token(token: "123456:ABC-DEF")
      {:ok, "123456:ABC-DEF"}

      iex> TokenManager.resolve_token([])
      {:error, :token_not_configured}
  """
  @spec resolve_token(keyword()) :: {:ok, token()} | {:error, atom()}
  def resolve_token(opts \\ []) do
    token = Keyword.get(opts, :token) || from_config() || from_env()

    case token do
      nil -> {:error, :token_not_configured}
      "" -> {:error, :token_not_configured}
      token -> validate_token(token)
    end
  end

  @doc """
  Resolves the Telegram bot token, raising on failure.

  ## Examples

      iex> TokenManager.resolve_token!(token: "123456:ABC-DEF")
      "123456:ABC-DEF"
  """
  @spec resolve_token!(keyword()) :: token() | no_return()
  def resolve_token!(opts \\ []) do
    case resolve_token(opts) do
      {:ok, token} -> token
      {:error, reason} -> raise "Telegram token error: #{reason}"
    end
  end

  @doc """
  Validates a Telegram bot token format.

  Telegram bot tokens have the format: `<bot_id>:<bot_secret>`
  where bot_id is a number and bot_secret is alphanumeric with dashes/underscores.

  ## Examples

      iex> TokenManager.validate_token("123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11")
      {:ok, "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"}

      iex> TokenManager.validate_token("invalid")
      {:error, :invalid_token_format}
  """
  @spec validate_token(token()) :: {:ok, token()} | {:error, atom()}
  def validate_token(token) when is_binary(token) do
    if valid_token_format?(token) do
      {:ok, token}
    else
      {:error, :invalid_token_format}
    end
  end

  def validate_token(_), do: {:error, :invalid_token_format}

  @doc """
  Checks if a token has valid Telegram bot token format.

  ## Examples

      iex> TokenManager.valid_token_format?("123456:ABC-DEF")
      true

      iex> TokenManager.valid_token_format?("invalid")
      false
  """
  @spec valid_token_format?(token()) :: boolean()
  def valid_token_format?(token) when is_binary(token) do
    case String.split(token, ":", parts: 2) do
      [bot_id, bot_secret] ->
        bot_id =~ ~r/^\d+$/ and bot_secret != "" and String.length(bot_secret) >= 10

      _ ->
        false
    end
  end

  def valid_token_format?(_), do: false

  @doc """
  Masks a token for safe logging.

  Shows only the first 4 and last 4 characters.

  ## Examples

      iex> TokenManager.mask_token("123456:ABC-DEF1234ghIkl")
      "1234...ghIkl"
  """
  @spec mask_token(token()) :: String.t()
  def mask_token(token) when is_binary(token) and byte_size(token) > 8 do
    first = String.slice(token, 0, 4)
    last = String.slice(token, -4, 4)
    "#{first}...#{last}"
  end

  def mask_token(_), do: "***"

  @doc """
  Constant-time comparison of two tokens to prevent timing attacks.

  ## Examples

      iex> TokenManager.constant_time_compare("abc", "abc")
      true

      iex> TokenManager.constant_time_compare("abc", "def")
      false
  """
  @spec constant_time_compare(token(), token()) :: boolean()
  def constant_time_compare(a, b) when is_binary(a) and is_binary(b) do
    if byte_size(a) == byte_size(b) do
      a_chars = to_charlist(a)
      b_chars = to_charlist(b)

      Enum.zip(a_chars, b_chars)
      |> Enum.reduce(0, fn {x, y}, acc -> Bitwise.bor(acc, Bitwise.bxor(x, y)) end)
      |> Kernel.==(0)
    else
      false
    end
  end

  def constant_time_compare(_, _), do: false

  # Private functions

  defp from_config do
    try do
      Lux.Config.telegram_bot_token()
    rescue
      _ -> nil
    end
  end

  defp from_env do
    System.get_env("TELEGRAM_BOT_TOKEN")
  end
end