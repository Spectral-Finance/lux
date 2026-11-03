defmodule Lux.Integrations.Coinbase.Signer do
  @moduledoc """
  Authentication and request signing for Coinbase Advanced Trade REST and WebSocket APIs.
  Supports HMAC-SHA256 signature generation: `timestamp + method + request_path + body`.
  """

  @doc """
  Signs request payload with Coinbase API Secret using HMAC-SHA256.
  """
  @spec sign(String.t(), String.t(), String.t(), String.t(), String.t()) :: String.t()
  def sign(timestamp, method, request_path, body, secret_key)
      when is_binary(timestamp) and is_binary(method) and is_binary(request_path) and is_binary(body) and is_binary(secret_key) do
    message = timestamp <> String.upcase(method) <> request_path <> body

    :crypto.mac(:hmac, :sha256, secret_key, message)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Prepares authentication headers for Coinbase Advanced Trade REST requests.
  """
  @spec auth_headers(String.t(), String.t(), String.t(), String.t(), String.t(), non_neg_integer() | nil) ::
          [{String.t(), String.t()}]
  def auth_headers(api_key, secret_key, method, request_path, body \\ "", timestamp \\ nil) do
    ts =
      if timestamp,
        do: to_string(timestamp),
        else: to_string(:os.system_time(:second))

    signature = sign(ts, method, request_path, body, secret_key)

    [
      {"CB-ACCESS-KEY", api_key},
      {"CB-ACCESS-SIGN", signature},
      {"CB-ACCESS-TIMESTAMP", ts},
      {"Content-Type", "application/json"},
      {"User-Agent", "Lux-Coinbase-Connector/1.0"}
    ]
  end
end
