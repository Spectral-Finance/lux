defmodule Lux.Integrations.DefiLlama do
  @moduledoc """
  Integration with the DeFiLlama API for accessing TVL, Yields, and Volume data.

  DeFiLlama provides open APIs for DeFi analytics.

  ## Usage
  DeFiLlama does not require API keys for its public endpoints.
  """

  @doc """
  Gets the configured DeFiLlama base URL.
  """
  @spec base_url() :: String.t()
  def base_url do
    "https://api.llama.fi"
  end

  @doc """
  Gets the default headers for DeFiLlama API requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"accept", "application/json"}
    ]
  end
end
