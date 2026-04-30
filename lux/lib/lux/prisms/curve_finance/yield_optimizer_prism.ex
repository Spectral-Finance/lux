defmodule Lux.Prisms.CurveFinance.YieldOptimizerPrism do
  @moduledoc """
  A prism that calculates optimal yield strategies across Curve Finance pools,
  considering base APY, CRV rewards, gas costs, and risk factors.

  ## Example

      iex> Lux.Prisms.CurveFinance.YieldOptimizerPrism.run(%{amount: 10000, tokens: ["USDC"]})
      {:ok, %{strategy: %{...}, expected_apy: 0.052, risk_score: 0.85}}

      iex> Lux.Prisms.CurveFinance.YieldOptimizerPrism.run(%{amount: 50000, tokens: ["DAI", "USDC"], risk_tolerance: :conservative})
      {:ok, %{strategy: %{...}, expected_apy: 0.048, risk_score: 0.92}}
  """

  @doc """
  Calculates the optimal yield strategy for a given investment.

  ## Parameters
    - `amount` - Investment amount in USD
    - `tokens` - Tokens to invest (e.g., ["USDC", "DAI"])
    - `risk_tolerance` - Risk level: :conservative, :moderate, :aggressive (default: :moderate)
    - `time_horizon` - Investment period in days (default: 30)
    - `include_boost` - Include veCRV boost calculations (default: true)

  ## Returns
    - `{:ok, strategy}` on success with optimized strategy
    - `{:error, reason}` on failure
  """
  def run(params \\ %{}) do
    params = normalize_params(params)

    with {:ok, pool_data} <- fetch_available_pools(params),
         {:ok, strategies} <- evaluate_strategies(pool_data, params),
         {:ok, optimal} <- select_optimal_strategy(strategies, params) do
      result = %{
        strategy: optimal,
        expected_apy: optimal.total_apy,
        expected_return_usd: params.amount * optimal.total_apy * (params.time_horizon / 365),
        risk_score: optimal.risk_score,
        gas_estimate: optimal.gas_estimate,
        alternatives: Enum.take(strategies, 3),
        last_updated: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Compares multiple strategies side by side.
  """
  def compare_strategies(params \\ %{}) do
    params = normalize_params(params)

    with {:ok, pool_data} <- fetch_available_pools(params),
         {:ok, strategies} <- evaluate_strategies(pool_data, params) do
      comparison =
        strategies
        |> Enum.map(fn s ->
          %{
            pool: s.pool_name,
            base_apy: s.base_apy,
            crv_apy: s.crv_apy,
            total_apy: s.total_apy,
            risk_score: s.risk_score,
            tvl: s.tvl,
            gas_estimate: s.gas_estimate,
            recommendation: s.recommendation
          }
        end)

      {:ok, %{strategies: comparison, count: length(comparison)}}
    end
  end

  # --- Private Functions ---

  defp normalize_params(params) when is_map(params) do
    params
    |> Map.new(fn {k, v} -> {normalize_key(k), v} end)
    |> Map.put_new(:risk_tolerance, :moderate)
    |> Map.put_new(:time_horizon, 30)
    |> Map.put_new(:include_boost, true)
  end

  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
  defp normalize_key(key) when is_atom(key), do: key

  defp fetch_available_pools(params) do
    tokens = Map.get(params, :tokens, ["USDC"])

    pools = [
      %{
        address: "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7",
        name: "3pool (DAI/USDC/USDT)",
        coins: ["DAI", "USDC", "USDT"],
        tvl: 850_000_000,
        base_apy: 0.032,
        crv_apy: 0.020,
        total_apy: 0.052,
        risk_score: 0.92,
        gas_estimate: 180_000,
        in_rebalance: false,
        recommendation: "Low risk, stable yield. Best for conservative investors."
      },
      %{
        address: "0x4c9aed14a4fd322f89707187f5a2d295d88bef1e",
        name: "stETH Pool",
        coins: ["ETH", "stETH"],
        tvl: 1_200_000_000,
        base_apy: 0.025,
        crv_apy: 0.020,
        total_apy: 0.045,
        risk_score: 0.88,
        gas_estimate: 200_000,
        in_rebalance: false,
        recommendation: "Liquid staking exposure. Moderate risk with ETH correlation."
      },
      %{
        address: "0xa5407eae9ba41425113d2f07db54d6d49899ae69",
        name: "TriCrypto Pool",
        coins: ["USDT", "WBTC", "WETH"],
        tvl: 650_000_000,
        base_apy: 0.065,
        crv_apy: 0.024,
        total_apy: 0.089,
        risk_score: 0.72,
        gas_estimate: 250_000,
        in_rebalance: false,
        recommendation: "Higher yield with crypto volatility. Suitable for aggressive investors."
      },
      %{
        address: "0x06df3b2bbb68adc8b0e302443692037ed9f91b42",
        name: "MetaPool (FRAX/3CRV)",
        coins: ["FRAX", "3CRV"],
        tvl: 180_000_000,
        base_apy: 0.045,
        crv_apy: 0.022,
        total_apy: 0.067,
        risk_score: 0.82,
        gas_estimate: 220_000,
        in_rebalance: false,
        recommendation: "Algorithmic stablecoin exposure. Moderate risk."
      }
    ]

    filtered =
      pools
      |> Enum.filter(fn pool ->
        Enum.any?(pool.coins, fn coin -> coin in tokens or "3CRV" in tokens end)
      end)

    {:ok, filtered}
  end

  defp evaluate_strategies(pools, params) do
    risk_tolerance = params.risk_tolerance
    include_boost = params.include_boost
    amount = params.amount

    strategies =
      pools
      |> Enum.map(fn pool ->
        # Apply risk tolerance filter
        risk_adjusted_apy =
          case risk_tolerance do
            :conservative -> pool.total_apy * 0.9
            :moderate -> pool.total_apy
            :aggressive -> pool.total_apy * 1.1
          end

        # Apply veCRV boost if enabled
        boosted_apy =
          if include_boost do
            risk_adjusted_apy * 1.5  # Max 2.5x boost, using average 1.5x
          else
            risk_adjusted_apy
          end

        # Calculate expected return
        expected_return = amount * boosted_apy * (params.time_horizon / 365)

        # Gas cost estimation (in USD, assuming 20 gwei gas price)
        gas_cost_usd = pool.gas_estimate * 20 * 0.000000001 * 3500  # ETH price ~$3500

        %{
          pool_address: pool.address,
          pool_name: pool.name,
          coins: pool.coins,
          tvl: pool.tvl,
          base_apy: pool.base_apy,
          crv_apy: pool.crv_apy,
          total_apy: boosted_apy,
          risk_score: pool.risk_score,
          gas_estimate: pool.gas_estimate,
          gas_cost_usd: gas_cost_usd,
          expected_return_usd: expected_return,
          net_return_usd: expected_return - gas_cost_usd,
          recommendation: pool.recommendation
        }
      end)
      |> Enum.sort_by(& &1.net_return_usd, :desc)

    {:ok, strategies}
  end

  defp select_optimal_strategy(strategies, params) do
    risk_tolerance = params.risk_tolerance

    # Filter by minimum risk score based on tolerance
    min_risk =
      case risk_tolerance do
        :conservative -> 0.85
        :moderate -> 0.70
        :aggressive -> 0.50
      end

    filtered = Enum.filter(strategies, fn s -> s.risk_score >= min_risk end)

    case filtered do
      [] ->
        # Fall back to highest TVL pool
        case strategies do
          [best | _] -> {:ok, best}
          [] -> {:error, :no_suitable_pools}
        end

      [best | _] ->
        {:ok, best}
    end
  end
end
