defmodule Lux.Integrations.Binance do
  @moduledoc """
  Common settings and functions for Binance API integration.
  """

  @doc """
  Common headers for Binance API calls.
  """
  def headers do
    api_key = Application.get_env(:lux, :api_keys)[:binance_api_key]
    [
      {"Content-Type", "application/json"},
      {"X-MBX-APIKEY", api_key}
    ]
  end

  @doc """
  Signs the query string or body parameters for Binance authenticated endpoints.
  """
  def sign_params(params) when is_map(params) do
    secret = Application.get_env(:lux, :api_keys)[:binance_api_secret] || ""
    timestamp = System.os_time(:millisecond)

    params_with_ts = Map.put(params, :timestamp, timestamp)
    query_string = URI.encode_query(params_with_ts)

    signature = :crypto.mac(:hmac, :sha256, secret, query_string)
                |> Base.encode16(case: :lower)

    Map.put(params_with_ts, :signature, signature)
  end

  @doc """
  Auth settings for Binance API calls.
  """
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth/1
    }
  end

  @doc """
  Adds Binance authentication (headers and signature).
  """
  @spec add_auth(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth(%Lux.Lens{} = lens) do
    api_key = Application.get_env(:lux, :api_keys)[:binance_api_key]
    new_headers = [{"X-MBX-APIKEY", api_key} | lens.headers]

    # If it's an authenticated request, sign the parameters
    params = lens.params || %{}
    signed_params = sign_params(params)

    %{lens | headers: new_headers, params: signed_params}
  end
end
