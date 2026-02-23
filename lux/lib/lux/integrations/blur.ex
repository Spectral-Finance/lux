defmodule Lux.Integrations.Blur do
  @moduledoc """
  Common settings and functions for Blur NFT marketplace API integration.

  Blur provides public endpoints for collection and NFT data with no API key
  required for read-only access.

  ## Configuration

  No API key required for public endpoints. Configure an optional auth token:

      config :lux, :api_keys,
        blur: "your_blur_auth_token"

  ## Rate Limits

  Public endpoints: ~10 requests/second
  """

  @base_url "https://core-api.prod.blur.io/v1"

  @doc "Returns the Blur API base URL."
  def base_url, do: @base_url

  @doc "Common headers for Blur API calls."
  def headers, do: [{"Content-Type", "application/json"}, {"accept", "application/json"}]

  @doc "Auth settings for Blur API calls (optional token)."
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc "Adds Blur auth token header if configured."
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    case Application.get_env(:lux, :api_keys)[:blur] do
      nil -> lens
      token -> %{lens | headers: lens.headers ++ [{"authToken", token}]}
    end
  end
end
