defmodule Lux.Integrations.SushiSwap.Bridge do
  @moduledoc """
  Cross-chain route, bridge safety, liquidity, and position helpers for SushiSwap.
  """

  alias Lux.Integrations.SushiSwap
  alias Lux.Integrations.SushiSwap.Client

  @default_policy %{
    allowed_providers: [:sushixswap, :lifi, :stargate, :cctp, :route_processor],
    max_price_impact: 0.03,
    max_gas_usd: 75.0,
    min_liquidity_usd: 100_000.0,
    max_eta_seconds: 1_800,
    min_confirmations: 12
  }

  @doc "Builds a bridge quote request and optionally calls Sushi's quote API."
  @spec bridge_quote(map(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def bridge_quote(params, opts \\ []) do
    opts = opts_map(opts)

    with {:ok, pair} <-
           SushiSwap.bridge_pair(value(params, :from_chain), value(params, :to_chain)) do
      request = %{
        chain_id: pair.from_chain_id,
        to_chain_id: pair.to_chain_id,
        token_in: value(params, :token_in),
        token_out: value(params, :token_out),
        amount: value(params, :amount),
        recipient: value(params, :recipient),
        slippage: value(params, :slippage, 0.005),
        referrer: value(opts, :referrer, "lux")
      }

      if value(opts, :live, false) do
        request
        |> quote_params()
        |> then(&Client.quote(pair.from_chain_id, &1, opts))
        |> case do
          {:ok, quote} ->
            {:ok, Map.merge(pair, %{request: request, quote: normalize_quote(quote)})}

          error ->
            error
        end
      else
        {:ok, Map.merge(pair, %{request: request, quote: synthetic_quote(request, opts)})}
      end
    end
  end

  @doc "Scores bridge routes and returns the safest economic route first."
  @spec optimize_routes([map()], keyword() | map()) :: [map()]
  def optimize_routes(routes, opts \\ []) when is_list(routes) do
    policy = policy(opts)

    routes
    |> Enum.map(&score_route(&1, policy))
    |> Enum.sort_by(& &1.score, :desc)
  end

  @doc "Verifies bridge safety constraints."
  @spec verify_bridge_security(map(), keyword() | map()) :: {:ok, map()} | {:error, [String.t()]}
  def verify_bridge_security(route, opts \\ []) do
    policy = policy(opts)
    alerts = bridge_alerts(route, policy)

    if alerts == [] do
      {:ok, Map.put(route, :security_status, :verified)}
    else
      {:error, alerts}
    end
  end

  @doc "Returns monitoring state and alerts for a bridge transfer."
  @spec monitor_bridge(map(), keyword() | map()) :: map()
  def monitor_bridge(transfer, opts \\ []) do
    policy = policy(opts)
    confirmations = numeric(value(transfer, :confirmations, 0))
    age_seconds = numeric(value(transfer, :age_seconds, 0))
    eta_seconds = numeric(value(transfer, :eta_seconds, 0))

    alerts =
      []
      |> maybe_add(
        confirmations < policy.min_confirmations,
        "waiting for source-chain confirmations"
      )
      |> maybe_add(eta_seconds > policy.max_eta_seconds, "bridge ETA exceeds policy")
      |> maybe_add(age_seconds > policy.max_eta_seconds * 2, "bridge transfer is stale")

    %{
      status: if(alerts == [], do: :healthy, else: :attention_required),
      confirmations: confirmations,
      eta_seconds: eta_seconds,
      alerts: alerts
    }
  end

  @doc "Builds a liquidity provision plan for a Sushi pool."
  @spec liquidity_plan(map(), keyword() | map()) :: map()
  def liquidity_plan(pool, opts \\ []) do
    target_ratio = numeric(value(opts, :target_ratio, 0.5))
    token_a_value = numeric(value(pool, :token_a_value_usd, 0))
    token_b_value = numeric(value(pool, :token_b_value_usd, 0))
    total = token_a_value + token_b_value
    current_ratio = if total == 0, do: target_ratio, else: token_a_value / total
    drift = current_ratio - target_ratio

    %{
      pool: value(pool, :pool),
      total_value_usd: total,
      current_ratio: current_ratio,
      target_ratio: target_ratio,
      action: liquidity_action(drift),
      rebalance_value_usd: abs(drift) * total
    }
  end

  @doc "Ranks farms by risk-adjusted reward."
  @spec reward_optimization([map()], keyword() | map()) :: [map()]
  def reward_optimization(farms, opts \\ []) when is_list(farms) do
    risk_weight = numeric(value(opts, :risk_weight, 0.5))

    farms
    |> Enum.map(fn farm ->
      apr = numeric(value(farm, :apr, 0))
      reward_apr = numeric(value(farm, :reward_apr, 0))
      risk = numeric(value(farm, :risk_score, 0))
      Map.put(farm, :optimized_score, apr + reward_apr - risk * risk_weight)
    end)
    |> Enum.sort_by(& &1.optimized_score, :desc)
  end

  @doc "Summarizes Sushi positions with token prices."
  @spec position_tracking([map()], map()) :: map()
  def position_tracking(positions, prices \\ %{}) when is_list(positions) do
    enriched =
      Enum.map(positions, fn position ->
        token_a = String.downcase(to_string(value(position, :token_a)))
        token_b = String.downcase(to_string(value(position, :token_b)))
        amount_a = numeric(value(position, :amount_a, 0))
        amount_b = numeric(value(position, :amount_b, 0))

        value_usd =
          amount_a * numeric(Map.get(prices, token_a, 0)) +
            amount_b * numeric(Map.get(prices, token_b, 0))

        Map.put(position, :value_usd, value_usd)
      end)

    %{
      positions: enriched,
      total_value_usd: enriched |> Enum.map(& &1.value_usd) |> Enum.sum()
    }
  end

  @doc "Returns a compact dashboard payload for SushiSwap bridge operations."
  @spec dashboard(map(), keyword() | map()) :: map()
  def dashboard(input, opts \\ []) do
    routes = optimize_routes(value(input, :routes, []), opts)
    positions = position_tracking(value(input, :positions, []), value(input, :prices, %{}))
    transfers = Enum.map(value(input, :transfers, []), &monitor_bridge(&1, opts))

    %{
      best_route: List.first(routes),
      routes: routes,
      positions: positions,
      transfers: transfers,
      unhealthy_transfers: Enum.count(transfers, &(&1.status != :healthy))
    }
  end

  defp quote_params(request) do
    %{
      tokenIn: request.token_in,
      tokenOut: request.token_out,
      amount: request.amount,
      recipient: request.recipient,
      toChainId: request.to_chain_id,
      slippagePercentage: request.slippage,
      referrer: request.referrer
    }
  end

  defp synthetic_quote(request, opts) do
    amount = numeric(request.amount)
    slippage = numeric(request.slippage)
    gas_usd = numeric(value(opts, :gas_usd, 8.5))

    %{
      amount_in: amount,
      estimated_amount_out: amount * (1 - slippage),
      price_impact: slippage,
      gas_usd: gas_usd,
      provider: value(opts, :provider, :sushixswap),
      route: [request.chain_id, request.to_chain_id]
    }
  end

  defp normalize_quote(quote) do
    %{
      amount_in: numeric(value(quote, :amountIn, value(quote, :amount_in, 0))),
      estimated_amount_out:
        numeric(value(quote, :assumedAmountOut, value(quote, :amount_out, 0))),
      price_impact: numeric(value(quote, :priceImpact, value(quote, :price_impact, 0))),
      gas_usd: numeric(value(quote, :gasSpent, value(quote, :gas_usd, 0))),
      provider: value(quote, :provider, :route_processor),
      raw: quote
    }
  end

  defp score_route(route, policy) do
    amount_out = numeric(value(route, :estimated_amount_out, value(route, :amount_out, 0)))
    gas_usd = numeric(value(route, :gas_usd, 0))
    price_impact = numeric(value(route, :price_impact, 0))
    eta_seconds = numeric(value(route, :eta_seconds, 0))
    alerts = bridge_alerts(route, policy)
    penalty = length(alerts) * 1_000 + price_impact * 10_000 + eta_seconds / 10

    route
    |> Map.put(:alerts, alerts)
    |> Map.put(:score, amount_out - gas_usd - penalty)
  end

  defp bridge_alerts(route, policy) do
    provider = value(route, :provider)

    []
    |> maybe_add(provider not in policy.allowed_providers, "bridge provider is not allowed")
    |> maybe_add(
      numeric(value(route, :price_impact, 0)) > policy.max_price_impact,
      "price impact exceeds policy"
    )
    |> maybe_add(
      numeric(value(route, :gas_usd, 0)) > policy.max_gas_usd,
      "gas estimate exceeds policy"
    )
    |> maybe_add(
      numeric(value(route, :liquidity_usd, policy.min_liquidity_usd)) < policy.min_liquidity_usd,
      "route liquidity is below policy"
    )
    |> maybe_add(
      numeric(value(route, :eta_seconds, 0)) > policy.max_eta_seconds,
      "bridge ETA exceeds policy"
    )
  end

  defp policy(opts) do
    Map.merge(@default_policy, opts_map(value(opts, :policy, %{})))
  end

  defp liquidity_action(drift) when drift > 0.05, do: :add_token_b_or_remove_token_a
  defp liquidity_action(drift) when drift < -0.05, do: :add_token_a_or_remove_token_b
  defp liquidity_action(_drift), do: :hold

  defp maybe_add(alerts, true, message), do: [message | alerts]
  defp maybe_add(alerts, false, _message), do: alerts

  defp value(map, key, default \\ nil)
  defp value(map, key, default) when is_map(map), do: map_get(map, key, default)
  defp value(list, key, default) when is_list(list), do: Keyword.get(list, key, default)

  defp map_get(map, key, default) do
    string_key = to_string(key)

    cond do
      Map.has_key?(map, key) -> Map.fetch!(map, key)
      Map.has_key?(map, string_key) -> Map.fetch!(map, string_key)
      true -> default
    end
  end

  defp opts_map(opts) when is_map(opts), do: opts
  defp opts_map(opts) when is_list(opts), do: Map.new(opts)

  defp numeric(nil), do: 0.0
  defp numeric(value) when is_integer(value), do: value * 1.0
  defp numeric(value) when is_float(value), do: value

  defp numeric(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> 0.0
    end
  end
end
