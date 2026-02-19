defmodule Lux.Integrations.Coinbase do
  @moduledoc """
  Common settings and functions for Coinbase Advanced Trade API integration.

  Coinbase Advanced Trade API uses JWT (JSON Web Token) authentication with
  ES256 (ECDSA P-256) signing. Each request requires a unique JWT that includes
  the HTTP method and request path.

  ## Configuration

  Add the following to your config:

      config :lux, :api_keys,
        coinbase_api_key: "organizations/{org_id}/apiKeys/{key_id}",
        coinbase_api_secret: "-----BEGIN EC PRIVATE KEY-----\\n...\\n-----END EC PRIVATE KEY-----\\n"

  ## Rate Limiting

  The Coinbase Advanced Trade API enforces rate limits. This module provides
  built-in rate limit tracking and retry logic with exponential backoff.
  """

  @doc """
  Common request settings for Coinbase API calls.
  """
  def request_settings do
    %{
      headers: [{"Content-Type", "application/json"}],
      auth: %{
        type: :custom,
        auth_function: &__MODULE__.add_auth_header/1
      }
    }
  end

  @doc """
  Common headers for Coinbase API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for Coinbase API calls.
  """
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc """
  Adds Coinbase JWT authorization header.
  """
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    method = lens.method |> to_string() |> String.upcase()
    path = URI.parse(lens.url).path

    case Lux.Integrations.Coinbase.Client.generate_jwt(method, path) do
      {:ok, jwt} ->
        %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{jwt}"}]}

      {:error, _reason} ->
        lens
    end
  end
end
