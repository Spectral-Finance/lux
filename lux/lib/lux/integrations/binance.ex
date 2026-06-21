defmodule Lux.Integrations.Binance do
  @moduledoc """
  Core settings and authentication utilities for the Binance integration.
  Supports both Spot and Futures APIs.
  """

  @doc """
  Generates common headers for Binance API calls.
  """
  def headers do
    api_key = Application.get_env(:lux, :api_keys)[:binance_api_key]
    if api_key do
      [
        {"Content-Type", "application/json"},
        {"X-MBX-APIKEY", api_key}
      ]
    else
      [{"Content-Type", "application/json"}]
    end
  end

  @doc """
  Signs the query parameters or request body using HMAC SHA256.
  Used for signed endpoints.
  """
  def sign_params(params) when is_map(params) do
    secret = Application.get_env(:lux, :api_keys)[:binance_api_secret] || ""
    timestamp = System.os_time(:millisecond)

    params_with_ts = Map.put(params, :timestamp, timestamp)
    query_string = URI.encode_query(params_with_ts)

    signature =
      :crypto.mac(:hmac, :sha256, secret, query_string)
      |> Base.encode16(case: :lower)

    Map.put(params_with_ts, :signature, signature)
  end
end
