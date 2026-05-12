defmodule Lux.Lenses.Curve.GetPoolsLens do
  @moduledoc """
  A lens for fetching all Curve pools for a given network.
  This lens provides information about all active pools across different implementations.

  ## Pool Information
  Each pool includes:
  - `id`: Unique pool identifier
  - `name`: Human-readable pool name
  - `address`: Pool contract address
  - `lp_token_address`: LP token contract address
  - `coin_addresses`: Array of underlying token addresses
  - `coin_names`: Array of underlying token names
  - `coin_decimals`: Array of underlying token decimals
  - `pool_type`: Type of pool (e.g., "main", "crypto", "factory")
  - `implementation`: Pool implementation contract
  - `swap_fee`: Current swap fee
  - `admin_fee`: Current admin fee
  - `virtual_price`: Current virtual price of the LP token
  - `total_liquidity`: Total value locked in the pool
  - `usd_total_liquidity`: Total liquidity denominated in USD

  ## Supported Networks
  - ethereum, polygon, arbitrum, optimism, avalanche, fantom, gnosis, celo, base

  ## Examples
      iex> GetPoolsLens.focus(%{network: "ethereum"})
      {:ok, %{
        pools: [
          %{
            id: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
            name: "3Pool",
            address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
            coin_addresses: ["0x6B175474E89094C44Da98b954EedeAC495271d0F", ...],
            pool_type: "main",
            total_liquidity: 100000000.0,
            usd_total_liquidity: 100000000.0
          }
        ]
      }}

      iex> GetPoolsLens.focus(%{network: "invalid"})
      {:error, "Invalid network: invalid. Supported networks: ethereum, polygon, arbitrum, optimism, avalanche, fantom, gnosis, celo, base"}
  """

  alias Lux.Integrations.Curve
  require Logger

  use Lux.Lens,
    name: "Get Curve Pools",
    description: "Fetches all Curve pools for a given network",
    url: "#{Curve.base_url()}/getPools/:network",
    method: :get,
    headers: Curve.headers(),
    schema: %{
      type: :object,
      properties: %{
        network: %{
          type: :string,
          description: "Blockchain network to fetch pools for",
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

    Logger.debug("Curve GetPoolsLens before_focus: #{inspect(%{network: network, params: params})}")
    params
  end

  @doc """
  Transforms the Curve API response into a simpler format.

  The response is transformed to provide:
  - Consistent field types (float for numeric values)
  - Snake_case atom keys
  - Nested pool data with only relevant fields

  ## Examples
      iex> after_focus(%{
      ...>   "data" => %{
      ...>     "poolData" => [
      ...>       %{
      ...>         "id" => "0x...",
      ...>         "name" => "3Pool",
      ...>         "address" => "0x...",
      ...>         "lpTokenAddress" => "0x..."
      ...>       }
      ...>     ]
      ...>   }
      ...> })
      {:ok, %{pools: [%{id: "0x...", name: "3Pool", address: "0x..."}]}}

      iex> after_focus(%{"error" => "Not found"})
      {:error, "Not found"}
  """
  @impl true
  def after_focus(%{"data" => %{"poolData" => pool_data}} = response) when is_list(pool_data) do
    Logger.info("Successfully fetched #{length(pool_data)} pools from Curve API")

    transformed_pools = Enum.map(pool_data, &transform_pool/1)

    {:ok, %{pools: transformed_pools}}
  end

  def after_focus(%{"data" => %{"poolData" => pool_data}}) do
    Logger.info("Successfully fetched pools from Curve API (non-list response)")
    {:ok, %{pools: pool_data}}
  end

  def after_focus(%{"error" => error}) do
    Logger.error("Failed to fetch pools from Curve API - Error: #{inspect(error)}")
    {:error, error}
  end

  defp transform_pool(pool) do
    %{
      id: pool["id"],
      name: pool["name"],
      address: pool["address"],
      lp_token_address: pool["lpTokenAddress"],
      coin_addresses: pool["coinAddresses"],
      coin_names: pool["coinNames"],
      coin_decimals: pool["coinDecimals"],
      pool_type: pool["poolType"],
      implementation: pool["implementation"],
      swap_fee: pool["swapFee"],
      admin_fee: pool["adminFee"],
      virtual_price: pool["virtualPrice"],
      total_liquidity: pool["totalLiquidity"],
      usd_total_liquidity: pool["usdTotalLiquidity"]
    }
  end
end
