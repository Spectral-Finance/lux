defmodule Lux.Lenses.Curve.GetPricesLens do
  @moduledoc """
  A lens for fetching pool prices and subgraph data from the Curve API for a given network.
  This lens provides real-time pricing data, volumes, and liquidity information.

  ## Price Information
  The response includes:
  - `pool_id`: Unique identifier of the pool
  - `pool_address`: Contract address of the pool
  - `pool_name`: Human-readable pool name
  - `usd_total_liquidity`: Total liquidity denominated in USD
  - `total_volume_usd`: Total trading volume in USD
  - `volume_usd_24h`: 24-hour trading volume in USD
  - `fees_usd_24h`: 24-hour fees generated in USD
  - `token_prices`: Map of token addresses to their USD prices
  - `lp_token_price_usd`: Price of the LP token in USD
  - `base_apy`: Base APY for liquidity providers
  - `virtual_price`: Current virtual price of the LP token

  ## Supported Networks
  - ethereum, polygon, arbitrum, optimism, avalanche, fantom, gnosis, celo, base

  ## Examples
      iex> GetPricesLens.focus(%{network: "ethereum"})
      {:ok, %{
        prices: [
          %{
            pool_id: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
            pool_name: "3Pool",
            usd_total_liquidity: 100000000.0,
            volume_usd_24h: 5000000.0,
            fees_usd_24h: 5000.0,
            token_prices: %{
              "0x6B175474E89094C44Da98b954EedeAC495271d0F" => 1.0,
              "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" => 1.0
            }
          }
        ]
      }}

      iex> GetPricesLens.focus(%{network: "invalid"})
      {:error, "Invalid network: invalid. Supported networks: ethereum, polygon, arbitrum, optimism, avalanche, fantom, gnosis, celo, base"}
  """

  alias Lux.Integrations.Curve
  require Logger

  use Lux.Lens,
    name: "Get Curve Prices",
    description: "Fetches pool prices and subgraph data from the Curve API",
    url: "#{Curve.base_url()}/getSubgraphData/:network",
    method: :get,
    headers: Curve.headers(),
    schema: %{
      type: :object,
      properties: %{
        network: %{
          type: :string,
          description: "Blockchain network to fetch price data for",
          enum: ~w(ethereum polygon arbitrum optimism avalanche fantom gnosis celo base)
        }
      },
      required: ["network"]
    }

  @doc """
  Validates the network parameter before making the API request.

  ## Examples
      iex> before_focus(%{network: "ethereum"})
      %{network: "ethereum"}

      iex> before_focus(%{network: "invalid"})
      ** (ArgumentError) Invalid network: invalid. Supported networks: ethereum, polygon, arbitrum, optimism, avalanche, fantom, gnosis, celo, base
  """
  @impl true
  def before_focus(%{network: network} = params) do
    unless Curve.valid_network?(network) do
      raise ArgumentError,
        "Invalid network: #{network}. Supported networks: ethereum, polygon, arbitrum, optimism, avalanche, fantom, gnosis, celo, base"
    end

    Logger.debug("Curve GetPricesLens before_focus: #{inspect(%{network: network, params: params})}")
    params
  end

  @doc """
  Transforms the Curve subgraph data response into a simpler format.

  ## Examples
      iex> after_focus(%{
      ...>   "data" => %{
      ...>     "poolData" => [
      ...>       %{
      ...>         "id" => "0x...",
      ...>         "name" => "3Pool",
      ...>         "usdTotalLiquidity" => 100000000.0,
      ...>         "volumeUsd24h" => 5000000.0
      ...>       }
      ...>     ]
      ...>   }
      ...> })
      {:ok, %{prices: [%{pool_id: "0x...", pool_name: "3Pool", usd_total_liquidity: 100000000.0}]}}

      iex> after_focus(%{"error" => "Not found"})
      {:error, "Not found"}
  """
  @impl true
  def after_focus(%{"data" => %{"poolData" => pool_data}} = response) when is_list(pool_data) do
    Logger.info("Successfully fetched price data for #{length(pool_data)} pools from Curve API")

    transformed_prices = Enum.map(pool_data, &transform_pool_price/1)

    {:ok, %{prices: transformed_prices}}
  end

  def after_focus(%{"data" => %{"poolData" => pool_data}}) do
    Logger.info("Successfully fetched price data from Curve API (non-list response)")
    {:ok, %{prices: pool_data}}
  end

  def after_focus(%{"error" => error}) do
    Logger.error("Failed to fetch price data from Curve API - Error: #{inspect(error)}")
    {:error, error}
  end

  defp transform_pool_price(pool) do
    %{
      pool_id: pool["id"],
      pool_address: pool["address"],
      pool_name: pool["name"],
      usd_total_liquidity: pool["usdTotalLiquidity"],
      total_volume_usd: pool["totalVolumeUsd"],
      volume_usd_24h: pool["volumeUsd24h"],
      fees_usd_24h: pool["feesUsd24h"],
      token_prices: pool["tokenPrices"],
      lp_token_price_usd: pool["lpTokenPriceUsd"],
      base_apy: pool["baseApy"],
      virtual_price: pool["virtualPrice"]
    }
  end
end
