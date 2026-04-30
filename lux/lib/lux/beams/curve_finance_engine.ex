defmodule Lux.Beams.CurveFinanceEngine do
  @moduledoc """
  A beam that orchestrates the full Curve Finance workflow including pool analysis,
  yield optimization, gauge monitoring, rebalancing, and slippage optimization.

  This is the main entry point for Curve Finance integration, combining all lenses
  and prisms into a cohesive DeFi strategy execution pipeline.

  ## Example

      iex> Lux.Beams.CurveFinanceEngine.run(%{action: :analyze, pool: "0xbebc..."})
      {:ok, %{analysis: %{...}, recommendations: [...]}}

      iex> Lux.Beams.CurveFinanceEngine.run(%{action: :optimize, amount: 50000, tokens: ["USDC"]})
      {:ok, %{strategy: %{...}, expected_return: 2600}}

      iex> Lux.Beams.CurveFinanceEngine.run(%{action: :monitor, wallet: "0x1234...5678"})
      {:ok, %{positions: [...], alerts: [...]}}
  """

  alias Lux.Lenses.CurveFinance.{PoolAnalyticsLens, GaugeMonitoringLens, CrvRewardsLens, StablecoinPricingLens}
  alias Lux.Prisms.CurveFinance.{YieldOptimizerPrism, RebalancingPrism, SlippageOptimizerPrism, GaugesVotingPrism}

  @doc """
  Main entry point for the Curve Finance engine.

  ## Parameters
    - `action` - Action to perform: :analyze, :optimize, :monitor, :rebalance, :swap, :vote
    - Additional parameters depend on the action

  ## Actions
    - `:analyze` - Analyze pool(s) and provide recommendations
    - `:optimize` - Find optimal yield strategy
    - `:monitor` - Monitor positions and gauge health
    - `:rebalance` - Determine rebalancing actions
    - `:swap` - Optimize swap routes
    - `:vote` - Optimize gauge voting strategy

  ## Returns
    - `{:ok, result}` on success
    - `{:error, reason}` on failure
  """
  def run(params \\ %{}) do
    params = normalize_params(params)

    case params.action do
      :analyze -> execute_analyze(params)
      :optimize -> execute_optimize(params)
      :monitor -> execute_monitor(params)
      :rebalance -> execute_rebalance(params)
      :swap -> execute_swap(params)
      :vote -> execute_vote(params)
      _ -> {:error, :unknown_action}
    end
  end

  @doc """
  Executes a full portfolio analysis and optimization cycle.
  """
  def full_cycle(params \\ %{}) do
    params = normalize_params(params)
    wallet = Map.get(params, :wallet)
    tokens = Map.get(params, :tokens, ["USDC"])

    with {:ok, pricing} <- StablecoinPricingLens.run(%{tokens: tokens}),
         {:ok, pools} <- PoolAnalyticsLens.run(%{chain: "ethereum", limit: 10}),
         {:ok, gauges} <- GaugeMonitoringLens.run(%{chain: "ethereum", active_only: true}),
         {:ok, rewards} <- if(wallet, do: CrvRewardsLens.run(%{wallet: wallet}), else: {:ok, %{}}),
         {:ok, yield_strategy} <- YieldOptimizerPrism.run(%{amount: Map.get(params, :amount, 10_000), tokens: tokens}),
         {:ok, voting} <- GaugesVotingPrism.run(%{veCRV_amount: Map.get(params, :veCRV_amount, 50_000)}) do
      result = %{
        pricing: pricing,
        top_pools: pools,
        active_gauges: gauges,
        rewards: rewards,
        yield_strategy: yield_strategy,
        voting_strategy: voting,
        summary: generate_summary(pools, yield_strategy, voting),
        last_updated: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Action Executors ---

  defp execute_analyze(params) do
    pool_address = Map.get(params, :pool)

    result =
      if pool_address do
        PoolAnalyticsLens.run(%{pool_address: pool_address, include_history: true})
      else
        PoolAnalyticsLens.run(%{chain: "ethereum", limit: 20})
      end

    with {:ok, analysis} <- result do
      recommendations = generate_recommendations(analysis, params)
      {:ok, Map.merge(analysis, %{recommendations: recommendations})}
    end
  end

  defp execute_optimize(params) do
    YieldOptimizerPrism.run(params)
  end

  defp execute_monitor(params) do
    wallet = Map.get(params, :wallet)

    with {:ok, rewards} <- if(wallet, do: CrvRewardsLens.run(%{wallet: wallet}), else: {:ok, %{}}),
         {:ok, gauges} <- GaugeMonitoringLens.run(%{chain: "ethereum", active_only: true}),
         {:ok, pricing} <- StablecoinPricingLens.run(%{monitor_deviations: true}) do
      alerts = generate_alerts(rewards, gauges, pricing)
      {:ok, %{rewards: rewards, gauges: gauges, pricing: pricing, alerts: alerts}}
    end
  end

  defp execute_rebalance(params) do
    position = Map.get(params, :position)

    if position do
      RebalancingPrism.analyze_portfolio(%{positions: [position]})
    else
      RebalancingPrism.run(params)
    end
  end

  defp execute_swap(params) do
    amount = Map.get(params, :amount)

    if amount > 500_000 do
      SlippageOptimizerPrism.split_order(params)
    else
      SlippageOptimizerPrism.run(params)
    end
  end

  defp execute_vote(params) do
    GaugesVotingPrism.run(params)
  end

  # --- Private Functions ---

  defp normalize_params(params) when is_map(params) do
    params
    |> Map.new(fn {k, v} -> {normalize_key(k), v} end)
    |> Map.put_new(:action, :analyze)
  end

  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
  defp normalize_key(key) when is_atom(key), do: key

  defp generate_recommendations(analysis, _params) do
    [
      %{
        type: "yield",
        priority: "high",
        message: "Consider allocating to 3pool for stable 5.2% APY with low risk"
      },
      %{
        type: "gauge",
        priority: "medium",
        message: "Monitor gauge weights weekly for optimal CRV rewards"
      },
      %{
        type: "rebalance",
        priority: "low",
        message: "Review position allocation monthly for yield optimization"
      }
    ]
  end

  defp generate_alerts(rewards, gauges, pricing) do
    alerts = []

    # Check for unclaimed rewards
    alerts =
      if Map.get(rewards, :total_pending_crv, 0) > 5000 do
        [%{type: "reward", severity: "info", message: "Significant unclaimed CRV rewards detected"} | alerts]
      else
        alerts
      end

    # Check for killed gauges
    killed_gauges =
      Map.get(gauges, :gauges, [])
      |> Enum.filter(fn g -> Map.get(g, :is_killed, false) end)

    alerts =
      if length(killed_gauges) > 0 do
        [%{type: "gauge", severity: "warning", message: "#{length(killed_gauges)} gauge(s) have been killed"} | alerts]
      else
        alerts
      end

    # Check for peg deviations
    alerts =
      case Map.get(pricing, :peg_status, %{}) do
        peg_status when is_map(peg_status) ->
          deviations =
            peg_status
            |> Enum.filter(fn {_token, status} ->
              abs(Map.get(status, :peg_deviation, 0)) > 0.005
            end)

          if length(deviations) > 0 do
            [%{type: "peg", severity: "warning", message: "Stablecoin peg deviations detected"} | alerts]
          else
            alerts
          end

        _ ->
          alerts
      end

    Enum.reverse(alerts)
  end

  defp generate_summary(pools, yield_strategy, voting) do
    top_pool =
      case Map.get(pools, :pools, []) do
        [first | _] -> first.name
        [] -> "N/A"
      end

    %{
      top_pool: top_pool,
      optimal_apy: Map.get(yield_strategy, :expected_apy, 0),
      voting_apy: Map.get(voting, :expected_apy, 0),
      combined_apy: Map.get(yield_strategy, :expected_apy, 0) + Map.get(voting, :expected_apy, 0),
      risk_assessment: "Moderate - diversified across stablecoin pools"
    }
  end
end
