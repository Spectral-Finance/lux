defmodule Lux.Integrations.OpenSea do
  @moduledoc """
  Common settings and functions for OpenSea API v2 integration.

  ## Configuration

  Configure in your application config:

      config :lux, :api_keys,
        opensea: "your_opensea_api_key"

  The API key is optional for public endpoints but required for higher rate limits.
  Get a free API key at https://docs.opensea.io/reference/api-keys

  ## Rate Limits

  - Without API key: 4 requests/second
  - With API key: Up to 100 requests/second (varies by tier)
  """

  @base_url "https://api.opensea.io/api/v2"

  @doc "Returns the OpenSea API v2 base URL."
  def base_url, do: @base_url

  @doc "Common JSON content-type header for OpenSea API calls."
  def headers, do: [{"Content-Type", "application/json"}, {"accept", "application/json"}]

  @doc "Auth settings for OpenSea API calls using x-api-key header."
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc "Adds OpenSea API key header if configured."
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    case Application.get_env(:lux, :api_keys)[:opensea] do
      nil -> lens
      key -> %{lens | headers: lens.headers ++ [{"x-api-key", key}]}
    end
  end
end
