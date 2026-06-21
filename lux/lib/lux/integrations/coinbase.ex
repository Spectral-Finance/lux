defmodule Lux.Integrations.Coinbase do
  @moduledoc """
  Core settings and authentication utilities for the Coinbase Advanced Trade API integration.
  """

  @doc """
  Generates headers for Coinbase API calls including HMAC signatures for authenticated endpoints.
  """
  def headers(method, path, body \\ "") do
    api_key = Application.get_env(:lux, :api_keys)[:coinbase_api_key]
    api_secret = Application.get_env(:lux, :api_keys)[:coinbase_api_secret]

    base_headers = [{"Content-Type", "application/json"}]

    if api_key && api_secret do
      timestamp = System.os_time(:second) |> Integer.to_string()

      message = timestamp <> String.upcase(to_string(method)) <> path <> body

      # For standard HMAC based auth (some endpoints / legacy keys)
      signature =
        :crypto.mac(:hmac, :sha256, api_secret, message)
        |> Base.encode16(case: :lower)

      [
        {"CB-ACCESS-KEY", api_key},
        {"CB-ACCESS-SIGN", signature},
        {"CB-ACCESS-TIMESTAMP", timestamp}
        | base_headers
      ]
    else
      base_headers
    end
  end
end
