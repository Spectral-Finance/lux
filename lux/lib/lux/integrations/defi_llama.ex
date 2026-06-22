defmodule Lux.Integrations.DefiLlama do
  @moduledoc """
  Integration with the DeFiLlama API for accessing DeFi analytics data.

  DeFiLlama provides comprehensive analytics for DeFi protocols, including
  TVL, volume, yields, and protocol-specific metrics.

  ## Configuration

  No API key is required for public DeFiLlama APIs. However, you can configure
  custom base URLs in your `config/runtime.exs`:

      config :lux, Lux.Integrations.DefiLlama,
        base_url: "https://api.llama.fi",
        yields_url: "https://yields.llama.fi"
  """

  @doc """
  Gets the configured DeFiLlama base URL.
  Defaults to "https://api.llama.fi" if not configured.
  """
  @spec base_url() :: String.t()
  def base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:base_url, "https://api.llama.fi")
  end

  @doc """
  Gets the configured DeFiLlama yields base URL.
  Defaults to "https://yields.llama.fi" if not configured.
  """
  @spec yields_url() :: String.t()
  def yields_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:yields_url, "https://yields.llama.fi")
  end

  @doc """
  Gets the default headers for DeFiLlama API requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]
  end

  @doc """
  No authentication is required for public DeFiLlama endpoints.
  """
  @spec auth() :: map()
  def auth do
    %{type: :none}
  end
end
