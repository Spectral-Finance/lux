defmodule Lux.Integrations.X2Y2 do
  @moduledoc """
  Common settings and functions for X2Y2 NFT marketplace API integration.

  X2Y2 is a decentralized NFT marketplace on Ethereum providing competitive
  pricing and analytics for NFT collections.

  ## Configuration

  Configure in your application config:

      config :lux, :api_keys,
        x2y2: "your_x2y2_api_key"

  Get a free API key at https://x2y2.io/

  ## Rate Limits

  - Free tier: 60 requests/minute
  - With API key: Higher limits (varies by tier)
  """

  @base_url "https://api.x2y2.io/v1"

  @doc "Returns the X2Y2 API v1 base URL."
  def base_url, do: @base_url

  @doc "Common JSON content-type header for X2Y2 API calls."
  def headers, do: [{"Content-Type", "application/json"}, {"accept", "application/json"}]

  @doc "Auth settings for X2Y2 API calls using X-API-Key header."
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc "Adds X2Y2 API key header if configured."
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    case Application.get_env(:lux, :api_keys)[:x2y2] do
      nil -> lens
      key -> %{lens | headers: lens.headers ++ [{"X-API-Key", key}]}
    end
  end
end
