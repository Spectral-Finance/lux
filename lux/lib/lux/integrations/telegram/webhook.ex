defmodule Lux.Integrations.Telegram.Webhook do
  @moduledoc """
  Webhook helper functions for Telegram Bot API.

  Provides inbound request validation, verifying secret tokens using
  constant-time secure comparison.
  """

  @doc """
  Verifies the X-Telegram-Bot-Api-Secret-Token header against the expected secret.

  Can receive a `%Plug.Conn{}` struct or the header value directly as a string.

  Returns `true` if the tokens match, otherwise `false`.

  ## Examples

      iex> conn = %Plug.Conn{} |> Plug.Conn.put_req_header("x-telegram-bot-api-secret-token", "my-secret")
      iex> Webhook.verify_secret_token(conn, "my-secret")
      true

      iex> Webhook.verify_secret_token("header-value", "expected-secret")
      false
  """
  @spec verify_secret_token(Plug.Conn.t() | String.t(), String.t()) :: boolean()
  def verify_secret_token(%Plug.Conn{} = conn, expected_token) when is_binary(expected_token) do
    case Plug.Conn.get_req_header(conn, "x-telegram-bot-api-secret-token") do
      [header_val | _] -> verify_secret_token(header_val, expected_token)
      _ -> false
    end
  end

  def verify_secret_token(header_val, expected_token)
      when is_binary(header_val) and is_binary(expected_token) do
    # Plug.Crypto.secure_compare/2 raises an ArgumentError if the string lengths do not match
    if String.length(header_val) == String.length(expected_token) do
      Plug.Crypto.secure_compare(header_val, expected_token)
    else
      false
    end
  end

  def verify_secret_token(_, _), do: false
end
