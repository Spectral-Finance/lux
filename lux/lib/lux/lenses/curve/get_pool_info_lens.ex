defmodule Lux.Lenses.Curve.GetPoolInfoLens do
  @moduledoc """
  A lens for fetching detailed information about a specific Curve pool.
  This lens provides comprehensive pool metadata, token information, and liquidity data.

  ## Pool Information
  The response includes:
  - `id`: Unique pool identifier
  - `name`: Human-readable pool name
  - `address`: Pool contract address
  - `lp_token_address`: LP token contract address
  - `coin_addresses`: Array of underlying token addresses
  - `coin_names`: Array of underlying token names
  - `coin_symbols`: Array of underlying token symbols
  - `coin_decimals`: Array of underlying token decimals
  - `pool_type`: Type of pool (e.g., "main", "crypto", "factory")
  - `implementation`: Pool implementation contract address
  - `swap_fee`: Current swap fee as a decimal
  - `admin_fee`: Current admin fee as a decimal
  - `virtual_price`: Current virtual price of the LP token
  - `total_liquidity`: Total value locked in the pool
  - `usd_total_liquidity`: Total liquidity denominated in USD
  - `a`: Amplification coefficient
  - `gamma`: Gamma parameter (for crypto pools)
  - `fee`: Fee percentage
  - `admin_fee_override`: Admin fee override if set
  - `lp_token_supply`: Total supply of the LP token
  - `balances`: Array of coin balances in the pool

  ## Examples
      iex> GetPoolInfoLens.focus(%{
      ...>   pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
      ...> })
      {:ok, %{
        pool: %{
          id: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
          name: "3Pool",
          address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
          coin_names: ["DAI", "USDC", "USDT"],
          pool_type: "main",
          usd_total_liquidity: 100000000.0
        }
      }}

      iex> GetPoolInfoLens.focus(%{pool_address: "invalid"})
      {:error, "Invalid Ethereum address format: invalid"}
  """

  alias Lux.Integrations.Curve
  require Logger

  use Lux.Lens,
    name: "Get Curve Pool Info",
    description: "Fetches detailed information about a specific Curve pool",
    url: "#{Curve.base_url()}/getPool/:pool_address",
    method: :get,
    headers: Curve.headers(),
    schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "The address of the Curve pool to fetch info for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["pool_address"]
    }

  @doc """
  Validates the pool address parameter before making the API request.

  ## Examples
      iex> before_focus(%{pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"})
      %{pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"}

      iex> before_focus(%{pool_address: "invalid"})
      ** (ArgumentError) Invalid pool address format: invalid
  """
  @impl true
  def before_focus(%{pool_address: address} = params) do
    unless Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address) do
      raise ArgumentError, "Invalid pool address format: #{address}"
    end

    Logger.debug("Curve GetPoolInfoLens before_focus: #{inspect(%{pool_address: address, params: params})}")
    params
  end

  @doc """
  Transforms the Curve API response into a simpler format.

  ## Examples
      iex> after_focus(%{
      ...>   "data" => %{
      ...>     "poolData" => %{
      ...>       "name" => "3Pool",
      ...>       "address" => "0x..."
      ...>     }
      ...>   }
      ...> })
      {:ok, %{pool: %{name: "3Pool", address: "0x..."}}}

      iex> after_focus(%{"error" => "Pool not found"})
      {:error, "Pool not found"}
  """
  @impl true
  def after_focus(%{"data" => %{"poolData" => pool_data}} = response) when is_map(pool_data) do
    Logger.info("Successfully fetched pool info from Curve API: #{pool_data["name"] || pool_data["id"]}")

    transformed_pool = %{
      id: pool_data["id"],
      name: pool_data["name"],
      address: pool_data["address"],
      lp_token_address: pool_data["lpTokenAddress"],
      coin_addresses: pool_data["coinAddresses"],
      coin_names: pool_data["coinNames"],
      coin_symbols: pool_data["coinSymbols"],
      coin_decimals: pool_data["coinDecimals"],
      pool_type: pool_data["poolType"],
      implementation: pool_data["implementation"],
      swap_fee: pool_data["swapFee"],
      admin_fee: pool_data["adminFee"],
      virtual_price: pool_data["virtualPrice"],
      total_liquidity: pool_data["totalLiquidity"],
      usd_total_liquidity: pool_data["usdTotalLiquidity"],
      a: pool_data["a"],
      gamma: pool_data["gamma"],
      fee: pool_data["fee"],
      admin_fee_override: pool_data["adminFeeOverride"],
      lp_token_supply: pool_data["lpTokenSupply"],
      balances: pool_data["balances"]
    }

    {:ok, %{pool: transformed_pool}}
  end

  def after_focus(%{"error" => error}) do
    Logger.error("Failed to fetch pool info from Curve API - Error: #{inspect(error)}")
    {:error, error}
  end
end
