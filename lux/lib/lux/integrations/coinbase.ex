defmodule Lux.Integrations.Coinbase do
  @moduledoc """
  Common settings and functions for Coinbase Advanced Trade API integration.
  Supports API Key + Secret (HMAC-SHA256) authentication.
  """

  def headers, do: [{"Content-Type", "application/json"}]

  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    api_key = coinbase_api_key()
    api_secret = coinbase_api_secret()
    timestamp = Integer.to_string(System.system_time(:second))
    method = lens.method |> to_string() |> String.upcase()
    path = URI.parse(lens.url).path || "/"
    body = if lens.body, do: lens.body, else: ""
    message = timestamp <> method <> path <> body
    signature = sign(message, api_secret)

    %{lens | headers: lens.headers ++ [
      {"CB-ACCESS-KEY", api_key},
      {"CB-ACCESS-SIGN", signature},
      {"CB-ACCESS-TIMESTAMP", timestamp}
    ]}
  end

  def sign(message, secret) do
    :crypto.mac(:hmac, :sha256, secret, message)
    |> Base.encode16(case: :lower)
  end

  def coinbase_api_key do
    Application.get_env(:lux, :api_keys, [])[:coinbase_api_key] || ""
  end

  def coinbase_api_secret do
    Application.get_env(:lux, :api_keys, [])[:coinbase_api_secret] || ""
  end
end
