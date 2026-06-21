defmodule Lux.Integrations.Coinbase do
  @moduledoc """
  Common settings and functions for Coinbase Advanced Trade API integration.
  """

  @doc """
  Signs the request for Coinbase authenticated endpoints.
  """
  def sign_request(method, path, body \\ "") do
    api_key = Application.get_env(:lux, :api_keys)[:coinbase_api_key]
    secret = Application.get_env(:lux, :api_keys)[:coinbase_api_secret] || ""
    
    timestamp = System.os_time(:second) |> to_string()
    
    message = timestamp <> String.upcase(to_string(method)) <> path <> body
    
    signature = :crypto.mac(:hmac, :sha256, secret, message)
                |> Base.encode16(case: :lower)

    [
      {"CB-ACCESS-KEY", api_key},
      {"CB-ACCESS-SIGN", signature},
      {"CB-ACCESS-TIMESTAMP", timestamp},
      {"Content-Type", "application/json"}
    ]
  end

  @doc """
  Auth settings for Coinbase API calls via Lens/Prism behavior.
  """
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth/1
    }
  end

  @doc """
  Adds Coinbase authentication headers to a lens.
  """
  @spec add_auth(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth(%Lux.Lens{} = lens) do
    # Extract path from URL
    path = URI.parse(lens.url).path
    body = if lens.params == %{}, do: "", else: Jason.encode!(lens.params)
    
    headers = sign_request(lens.method, path, body)
    %{lens | headers: headers ++ lens.headers}
  end
end
