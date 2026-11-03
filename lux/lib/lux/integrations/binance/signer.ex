defmodule Lux.Integrations.Binance.Signer do
  @moduledoc """
  HMAC-SHA256 request signing and parameter formatting for Binance REST API endpoints.
  """

  @doc """
  Generates an HMAC-SHA256 signature for a query string or request body using the API secret.
  """
  @spec sign(String.t(), String.t()) :: String.t()
  def sign(query_string, secret_key) when is_binary(query_string) and is_binary(secret_key) do
    :crypto.mac(:hmac, :sha256, secret_key, query_string)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Appends timestamp, recvWindow, and cryptographic signature to parameters map.
  Returns url-encoded query string with signature.
  """
  @spec prepare_signed_query(map(), String.t(), non_neg_integer(), non_neg_integer()) :: String.t()
  def prepare_signed_query(params, secret_key, timestamp \\ nil, recv_window \\ 5000) do
    ts = timestamp || :os.system_time(:millisecond)

    params_with_time =
      params
      |> Map.put(:timestamp, ts)
      |> Map.put(:recvWindow, recv_window)

    query_string = URI.encode_query(params_with_time)
    signature = sign(query_string, secret_key)

    query_string <> "&signature=" <> signature
  end

  @doc """
  Prepares authentication headers for Binance requests.
  """
  @spec auth_headers(String.t()) :: [{String.t(), String.t()}]
  def auth_headers(api_key) when is_binary(api_key) do
    [
      {"X-MBX-APIKEY", api_key},
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"User-Agent", "Lux-Binance-Connector/1.0"}
    ]
  end
end
