defmodule Lux.Integrations.PancakeSwap do
  @moduledoc """
  Integration with PancakeSwap DEX for yield farming and liquidity provision across multiple chains.

  PancakeSwap is a multichain DEX offering swap, yield farming, staking, and liquidity pool features.

  ## Configuration

      config :lux, Lux.Integrations.PancakeSwap,
        base_url: System.get_env("PANCAKESWAP_API_URL") || "https://api.pancakeswap.finance/api/v1",
        router_v2: "0x10ED43C718714eb63d5aA57B78B54704E2568562",
        router_v3: "0x13f4EA83D0b40E6Fb3FBFB0A1C562A12a0311C6F",
        master_chef: "0x73feaa1eE314F8c580C3021b3DEB7F21c0aF26C0",
        supported_chains: [:bsc, :ethereum, :arbitrum, :base, :polygon]

  ## Usage

      # Get pool info
      PancakeSwap.get_pool_info("0x...")

      # Get farm APY
      PancakeSwap.get_farm_apy(123)

      # Auto-compound position
      PancakeSwap.auto_compound(position_id)
  """

  @base_url Application.get_env(:lux, __MODULE__, [])[:base_url] || "https://api.pancakeswap.finance/api/v1"
  @router_v2 Application.get_env(:lux, __MODULE__, [])[:router_v2] || "0x10ED43C718714eb63d5aA57B78B54704E2568562"
  @router_v3 Application.get_env(:lux, __MODULE__, [])[:router_v3] || "0x13f4EA83D0b40E6Fb3FBFB0A1C562A12a0311C6F"
  @master_chef Application.get_env(:lux, __MODULE__, [])[:master_chef] || "0x73feaa1eE314F8c580C3021b3DEB7F21c0aF26C0"

  @supported_chains [:bsc, :ethereum, :arbitrum, :base, :polygon]

  # ── Types ──────────────────────────────────────────────

  @type pool_info :: %{
    address: String.t(),
    token0: String.t(),
    token1: String.t(),
    reserve0: float(),
    reserve1: float(),
    total_supply: float(),
    fee_tier: integer(),
    chain: atom()
  }

  @type farm_info :: %{
    pid: integer(),
    alloc_point: integer(),
    deposit_fee_bp: integer(),
    total_locked: float(),
    apy: float(),
    earn_token: String.t(),
    chain: atom()
  }

  @type position :: %{
    id: String.t(),
    pid: integer(),
    amount: float(),
    pending_reward: float(),
    deposit_time: DateTime.t(),
    chain: atom()
  }

  @type auto_compound_result :: %{
    position_id: String.t(),
    compounded_amount: float(),
    new_pending_reward: float(),
    tx_hash: String.t(),
    chain: atom()
  }

  # ── Request Settings ──────────────────────────────────

  @doc """
  Common request settings for PancakeSwap API calls.
  """
  def request_settings do
    %{
      headers: [{"Content-Type", "application/json"}],
      auth: %{
        type: :custom,
        auth_function: &__MODULE__.add_auth_header/1
      }
    }
  end

  def headers, do: [{"Content-Type", "application/json"}]

  def auth do
    %{type: :custom, auth_function: &__MODULE__.add_auth_header/1}
  end

  def add_auth_header(opts) do
    api_key = Application.get_env(:lux, __MODULE__, [])[:api_key]
    if api_key do
      Keyword.put(opts, :headers, [{"X-API-Key", api_key} | headers()])
    else
      Keyword.put(opts, :headers, headers())
    end
  end

  # ── Chain Support ─────────────────────────────────────

  @doc """
  Returns list of supported chains.
  """
  def supported_chains, do: @supported_chains

  @doc """
  Gets the chain-specific API base URL.
  """
  def chain_base_url(:bsc), do: @base_url
  def chain_base_url(chain) when chain in @supported_chains do
    "https://api.pancakeswap.finance/api/v1/#{chain}"
  end

  # ── Pool Management ───────────────────────────────────

  @doc """
  Get information about a liquidity pool.
  """
  @spec get_pool_info(String.t(), keyword()) :: {:ok, pool_info()} | {:error, term()}
  def get_pool_info(pool_address, opts \\ []) do
    chain = Keyword.get(opts, :chain, :bsc)

    case api_get("/pools/#{pool_address}", chain) do
      {:ok, data} ->
        {:ok, %{
          address: data["address"],
          token0: data["token0"]["address"],
          token1: data["token1"]["address"],
          reserve0: parse_float(data["reserve0"]),
          reserve1: parse_float(data["reserve1"]),
          total_supply: parse_float(data["totalSupply"]),
          fee_tier: data["feeTier"] || 3000,
          chain: chain
        }}
      error -> error
    end
  end

  @doc """
  List top pools by TVL.
  """
  @spec list_top_pools(keyword()) :: {:ok, [pool_info()]} | {:error, term()}
  def list_top_pools(opts \\ []) do
    chain = Keyword.get(opts, :chain, :bsc)
    limit = Keyword.get(opts, :limit, 20)

    case api_get("/pools?sort=tvl&order=desc&limit=#{limit}", chain) do
      {:ok, data} when is_list(data) ->
        {:ok, Enum.map(data, &parse_pool_info(&1, chain))}
      error -> error
    end
  end

  @doc """
  Get pool liquidity depth.
  """
  @spec get_pool_liquidity(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_pool_liquidity(pool_address, opts \\ []) do
    chain = Keyword.get(opts, :chain, :bsc)
    api_get("/pools/#{pool_address}/liquidity", chain)
  end

  # ── Yield Farming ─────────────────────────────────────

  @doc """
  Get farm information including APY.
  """
  @spec get_farm_apy(integer(), keyword()) :: {:ok, farm_info()} | {:error, term()}
  def get_farm_apy(pid, opts \\ []) do
    chain = Keyword.get(opts, :chain, :bsc)

    case api_get("/farms/#{pid}", chain) do
      {:ok, data} ->
        {:ok, %{
          pid: pid,
          alloc_point: data["allocPoint"] || 0,
          deposit_fee_bp: data["depositFeeBP"] || 0,
          total_locked: parse_float(data["totalLocked"] || "0"),
          apy: parse_float(data["apy"] || "0"),
          earn_token: data["earnToken"] || "CAKE",
          chain: chain
        }}
      error -> error
    end
  end

  @doc """
  List all active farms.
  """
  @spec list_active_farms(keyword()) :: {:ok, [farm_info()]} | {:error, term()}
  def list_active_farms(opts \\ []) do
    chain = Keyword.get(opts, :chain, :bsc)

    case api_get("/farms?status=active&sort=apy&order=desc", chain) do
      {:ok, data} when is_list(data) ->
        {:ok, Enum.map(data, &parse_farm_info(&1, chain))}
      error -> error
    end
  end

  # ── Auto-Compounding ──────────────────────────────────

  @doc """
  Auto-compound a farming position — harvest rewards and reinvest.
  """
  @spec auto_compound(String.t(), keyword()) :: {:ok, auto_compound_result()} | {:error, term()}
  def auto_compound(position_id, opts \\ []) do
    chain = Keyword.get(opts, :chain, :bsc)

    with {:ok, position} <- get_position(position_id, chain: chain),
         {:ok, harvest} <- harvest_rewards(position_id, chain: chain),
         {:ok, compound} <- reinvest_reward(position, harvest, chain: chain) do
      {:ok, %{
        position_id: position_id,
        compounded_amount: compound["amount"],
        new_pending_reward: 0.0,
        tx_hash: compound["txHash"],
        chain: chain
      }}
    end
  end

  @doc """
  Get user farming position details.
  """
  @spec get_position(String.t(), keyword()) :: {:ok, position()} | {:error, term()}
  def get_position(position_id, opts \\ []) do
    chain = Keyword.get(opts, :chain, :bsc)

    case api_get("/positions/#{position_id}", chain) do
      {:ok, data} ->
        {:ok, %{
          id: position_id,
          pid: data["pid"],
          amount: parse_float(data["amount"] || "0"),
          pending_reward: parse_float(data["pendingReward"] || "0"),
          deposit_time: parse_datetime(data["depositTime"]),
          chain: chain
        }}
      error -> error
    end
  end

  @doc """
  List all positions for a user address.
  """
  @spec list_user_positions(String.t(), keyword()) :: {:ok, [position()]} | {:error, term()}
  def list_user_positions(user_address, opts \\ []) do
    chain = Keyword.get(opts, :chain, :bsc)
    api_get("/positions?user=#{user_address}", chain)
  end

  # ── Reward Management ────────────────────────────────

  @doc """
  Harvest pending rewards from a farming position.
  """
  @spec harvest_rewards(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def harvest_rewards(position_id, opts \\ []) do
    chain = Keyword.get(opts, :chain, :bsc)
    api_post("/positions/#{position_id}/harvest", %{}, chain)
  end

  @doc """
  Reinvest harvested rewards into the same pool.
  """
  @spec reinvest_reward(position(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def reinvest_reward(position, harvest, opts \\ []) do
    chain = Keyword.get(opts, :chain, :bsc)
    api_post("/positions/#{position.id}/compound", %{
      amount: harvest["amount"],
      pid: position.pid
    }, chain)
  end

  # ── APY Optimization ──────────────────────────────────

  @doc """
  Find the best farms sorted by risk-adjusted APY.
  """
  @spec find_best_farms(keyword()) :: {:ok, [farm_info()]} | {:error, term()}
  def find_best_farms(opts \\ []) do
    chain = Keyword.get(opts, :chain, :bsc)
    min_tvl = Keyword.get(opts, :min_tvl, 100_000)

    case list_active_farms(chain: chain) do
      {:ok, farms} ->
        filtered = farms
          |> Enum.filter(fn f -> f.total_locked >= min_tvl end)
          |> Enum.sort_by(fn f -> risk_adjusted_apy(f) end, :desc)
        {:ok, filtered}
      error -> error
    end
  end

  @doc """
  Calculate risk-adjusted APY based on TVL and fee tier.
  """
  def risk_adjusted_apy(farm) do
    tvl_multiplier = min(farm.total_locked / 1_000_000, 2.0)
    fee_penalty = farm.deposit_fee_bp / 10000
    farm.apy * tvl_multiplier * (1 - fee_penalty)
  end

  # ── Cross-Chain Bridging ──────────────────────────────

  @doc """
  Get bridge status between two chains.
  """
  @spec get_bridge_status(atom(), atom()) :: {:ok, map()} | {:error, term()}
  def get_bridge_status(from_chain, to_chain) do
    api_get("/bridge/status?from=#{from_chain}&to=#{to_chain}", :bsc)
  end

  @doc """
  Estimate bridge fees between chains.
  """
  @spec estimate_bridge_fee(atom(), atom(), float()) :: {:ok, map()} | {:error, term()}
  def estimate_bridge_fee(from_chain, to_chain, amount) do
    api_get("/bridge/estimate?from=#{from_chain}&to=#{to_chain}&amount=#{amount}", :bsc)
  end

  # ── Private Helpers ───────────────────────────────────

  defp api_get(path, chain) do
    url = chain_base_url(chain) <> path

    case HTTPoison.get(url, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        {:error, %{status: code, body: body}}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp api_post(path, payload, chain) do
    url = chain_base_url(chain) <> path

    case HTTPoison.post(url, Jason.encode!(payload), headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        {:error, %{status: code, body: body}}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0

  defp parse_datetime(ts) when is_integer(ts) do
    DateTime.from_unix!(ts)
  end
  defp parse_datetime(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end
  defp parse_datetime(_), do: DateTime.utc_now()

  defp parse_pool_info(data, chain) do
    %{
      address: data["address"],
      token0: data["token0"]["address"],
      token1: data["token1"]["address"],
      reserve0: parse_float(data["reserve0"]),
      reserve1: parse_float(data["reserve1"]),
      total_supply: parse_float(data["totalSupply"]),
      fee_tier: data["feeTier"] || 3000,
      chain: chain
    }
  end

  defp parse_farm_info(data, chain) do
    %{
      pid: data["pid"] || 0,
      alloc_point: data["allocPoint"] || 0,
      deposit_fee_bp: data["depositFeeBP"] || 0,
      total_locked: parse_float(data["totalLocked"] || "0"),
      apy: parse_float(data["apy"] || "0"),
      earn_token: data["earnToken"] || "CAKE",
      chain: chain
    }
  end
end