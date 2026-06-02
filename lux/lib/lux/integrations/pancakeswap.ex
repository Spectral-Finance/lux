defmodule Lux.Integrations.PancakeSwap do
  @moduledoc """
  PancakeSwap DEX Integration for yield farming and liquidity provision.

  Provides comprehensive integration with PancakeSwap's AMM across
  multiple chains (BSC, Ethereum, Arbitrum, Polygon, Base, etc.).

  ## Core Features

  - Multi-chain pool management and position tracking
  - Yield farming automation with auto-compounding strategies
  - Real-time price feeds and swap quotes
  - APY tracking and optimization
  - Reward token collection and reinvestment
  - Risk monitoring and position alerts

  ## Configuration

      config :lux, Lux.Integrations.PancakeSwap,
        chain_id: System.get_env("PANCAKESWAP_CHAIN_ID") || "56",
        base_url: System.get_env("PANCAKESWAP_API_URL") || "https://api.pancakeswap.finance",
        rpc_url: System.get_env("PANCAKESWAP_RPC_URL")

  ## Quick Start

      # Get current price of BNB/USDT
      {:ok, price} = Lux.Integrations.PancakeSwap.get_price(:BNB, :USDT)

      # Get a swap quote
      {:ok, quote} = Lux.Integrations.PancakeSwap.get_swap_quote(
        token_in: :CAKE,
        token_out: :BUSD,
        amount: "100"
      )

      # Track yield farming position
      {:ok, position} = Lux.Integrations.PancakeSwap.track_farm_position(
        pool_id: 1,
        staked_amount: 1000.0
      )
  """

  require Logger

  alias Lux.Integrations.PancakeSwap.{Client, Pools, Yield}

  @default_chain_id 56
  @default_base_url "https://tokens.pancakeswap.finance"

  @type token_symbol :: atom() | String.t()
  @type chain_id :: non_neg_integer()

  @doc """
  Gets the configured chain ID.
  """
  @spec chain_id() :: non_neg_integer()
  def chain_id do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:chain_id, @default_chain_id)
  end

  @doc """
  Gets the configured base URL for PancakeSwap API.
  """
  @spec base_url() :: String.t()
  def base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:base_url, @default_base_url)
  end

  @doc """
  Gets the configured RPC URL for on-chain calls.
  """
  @spec rpc_url() :: String.t() | nil
  def rpc_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:rpc_url)
  end

  @doc """
  Gets token information including decimals, symbol, and address.
  """
  @spec get_token_info(token_symbol(), chain_id()) ::
          {:ok, map()} | {:error, String.t()}
  def get_token_info(token, chain_id \\ chain_id()) do
    Client.get_token_info(normalize_token(token), chain_id)
  end

  @doc """
  Gets the current price of a token pair.

  Returns price in the quote token denomination.
  """
  @spec get_price(token_symbol(), token_symbol(), keyword()) ::
          {:ok, float()} | {:error, String.t()}
  def get_price(base_token, quote_token, opts \\ []) do
    chain = Keyword.get(opts, :chain_id, chain_id())
    Client.get_price(normalize_token(base_token), normalize_token(quote_token), chain)
  end

  @doc """
  Gets a swap quote for exchanging tokens.

  Returns estimated output amount, price impact, and route information.
  """
  @spec get_swap_quote(keyword()) :: {:ok, map()} | {:error, String.t()}
  def get_swap_quote(opts) do
    Client.get_swap_quote(opts)
  end

  @doc """
  Fetches all available liquidity pools.
  """
  @spec list_pools(keyword()) :: {:ok, [map()]} | {:error, String.t()}
  def list_pools(opts \\ []) do
    Pools.list_pools(opts)
  end

  @doc """
  Gets detailed information about a specific pool.
  """
  @spec get_pool(String.t() | non_neg_integer(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def get_pool(pool_id, opts \\ []) do
    Pools.get_pool(pool_id, opts)
  end

  @doc """
  Gets the current APY for a farming pool.
  """
  @spec get_pool_apy(String.t() | non_neg_integer(), keyword()) ::
          {:ok, float()} | {:error, String.t()}
  def get_pool_apy(pool_id, opts \\ []) do
    Pools.get_apy(pool_id, opts)
  end

  @doc """
  Tracks a yield farming position.

  Returns position details including estimated daily yield.
  """
  @spec track_farm_position(keyword()) :: {:ok, map()} | {:error, String.t()}
  def track_farm_position(opts) do
    Yield.track_position(opts)
  end

  @doc """
  Calculates estimated rewards for a yield farming position.
  """
  @spec calculate_rewards(keyword()) :: {:ok, map()} | {:error, String.t()}
  def calculate_rewards(opts) do
    Yield.calculate_rewards(opts)
  end

  @doc """
  Simulates auto-compounding returns over a time period.
  """
  @spec simulate_auto_compound(keyword()) :: {:ok, map()} | {:error, String.t()}
  def simulate_auto_compound(opts) do
    Yield.simulate_auto_compound(opts)
  end

  @doc """
  Lists top yield farming opportunities ranked by APY.
  """
  @spec top_yield_farms(keyword()) :: {:ok, [map()]} | {:error, String.t()}
  def top_yield_farms(opts \\ []) do
    Yield.top_farms(opts)
  end

  @doc """
  Gets risk assessment for a specific farm or pool.
  """
  @spec assess_risk(String.t() | non_neg_integer(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def assess_risk(pool_id, opts \\ []) do
    Yield.assess_risk(pool_id, opts)
  end

  defp normalize_token(token) when is_atom(token), do: Atom.to_string(token) |> String.upcase()
  defp normalize_token(token) when is_binary(token), do: String.upcase(token)
end
