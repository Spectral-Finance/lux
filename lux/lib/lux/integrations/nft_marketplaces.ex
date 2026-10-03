defmodule Lux.Integrations.NFTMarketplaces do
  @moduledoc """
  Integration module for NFT Marketplaces (OpenSea, Blur, LooksRare).

  Provides configuration management, standard headers, authentication helpers,
  and base URLs for multi-marketplace aggregation pipelines.

  ## Configuration

  In `config/runtime.exs`:

      config :lux, Lux.Integrations.NFTMarketplaces,
        opensea_api_key: System.get_env("OPENSEA_API_KEY"),
        blur_auth_token: System.get_env("BLUR_AUTH_TOKEN"),
        looksrare_api_key: System.get_env("LOOKSRARE_API_KEY"),
        default_chain: "ethereum"

  ## Environment Variables

      OPENSEA_API_KEY="your-opensea-key"
      BLUR_AUTH_TOKEN="your-blur-token"
      LOOKSRARE_API_KEY="your-looksrare-key"
  """

  @type marketplace :: :opensea | :blur | :looksrare
  @type headers :: [{String.t(), String.t()}]

  @opensea_base_url "https://api.opensea.io"
  @blur_base_url "https://api.blur.io"
  @looksrare_base_url "https://api.looksrare.org"

  @doc """
  Gets the base URL for the given marketplace.
  """
  @spec base_url(marketplace()) :: String.t()
  def base_url(:opensea), do: @opensea_base_url
  def base_url(:blur), do: @blur_base_url
  def base_url(:looksrare), do: @looksrare_base_url

  @doc """
  Gets configured OpenSea API key.
  """
  @spec opensea_api_key() :: String.t() | nil
  def opensea_api_key do
    get_config(:opensea_api_key) || System.get_env("OPENSEA_API_KEY")
  end

  @doc """
  Gets configured Blur Auth token.
  """
  @spec blur_auth_token() :: String.t() | nil
  def blur_auth_token do
    get_config(:blur_auth_token) || System.get_env("BLUR_AUTH_TOKEN")
  end

  @doc """
  Gets configured LooksRare API key.
  """
  @spec looksrare_api_key() :: String.t() | nil
  def looksrare_api_key do
    get_config(:looksrare_api_key) || System.get_env("LOOKSRARE_API_KEY")
  end

  @doc """
  Returns standardized request headers for a marketplace.
  """
  @spec headers(marketplace()) :: headers()
  def headers(:opensea) do
    base = [
      {"accept", "application/json"},
      {"user-agent", "Lux-NFT-Aggregator/1.0"}
    ]

    case opensea_api_key() do
      nil -> base
      key -> [{"x-api-key", key} | base]
    end
  end

  def headers(:blur) do
    base = [
      {"accept", "application/json"},
      {"user-agent", "Lux-Blur-Connector/1.0"}
    ]

    case blur_auth_token() do
      nil -> base
      token -> [{"authorization", "Bearer #{token}"}, {"blur-auth", token} | base]
    end
  end

  def headers(:looksrare) do
    base = [
      {"accept", "application/json"},
      {"user-agent", "Lux-LooksRare-Connector/1.0"}
    ]

    case looksrare_api_key() do
      nil -> base
      key -> [{"x-looksrare-api-key", key} | base]
    end
  end

  defp get_config(key) do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key)
  end
end
