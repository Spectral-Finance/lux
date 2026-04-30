defmodule Lux.Prisms.CurveFinance.SlippageOptimizerPrism do
  @moduledoc """
  A prism that calculates optimal swap routes and parameters to minimize slippage
  on Curve Finance large trades, including multi-hop routing and dynamic fee optimization.

  ## Example

      iex> Lux.Prisms.CurveFinance.SlippageOptimizerPrism.run(%{from: "USDC", to: "DAI", amount: 100000})
      {:ok, %{route: [...], slippage: 0.0001, estimated_output: 99990}}

      iex> Lux.Prisms.CurveFinance.SlippageOptimizerPrism.run(%{from: "USDC", to: "FRAX", amount: 500000, max_hops: 2})
      {:ok, %{route: [...], slippage: 0.0003, estimated_output: 499850}}
  """

  @doc """
  Calculates the optimal swap route to minimize slippage.

  ## Parameters
    - `from` - Source token symbol
    - `to` - Destination token symbol
    - `amount` - Amount to swap (in token units)
    - `max_hops` - Maximum number of hops (default: 2)
    - `max_slippage` - Maximum acceptable slippage (default: 0.001 = 0.1%)

  ## Returns
    - `{:ok, route}` on success with optimal swap route
    - `{:error, reason}` on failure
  """
  def run(params \\ %{}) do
    params = normalize_params(params)

    with {:ok, routes} <- find_routes(params),
         {:ok, optimal} <- select_optimal_route(routes, params) do
      result = %{
        route: optimal.route,
        slippage: optimal.slippage,
        estimated_output: optimal.estimated_output,
        price_impact: optimal.price_impact,
        fee: optimal.fee,
        gas_estimate: optimal.gas_estimate,
        alternatives: Enum.take(routes -- [optimal], 2),
        last_updated: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Splits a large order into multiple smaller trades to minimize slippage.
  """
  def split_order(params \\ %{}) do
    params = normalize_params(params)
    amount = Map.get(params, :amount, 1_000_000)
    max_single_trade = Map.get(params, :max_single_trade, 100_000)

    num_splits = max(1, ceil(amount / max_single_trade))
    split_amounts = split_amount_evenly(amount, num_splits)

    trades =
      split_amounts
      |> Enum.with_index()
      |> Enum.map(fn {trade_amount, index} ->
        {:ok, route} = find_routes(Map.put(params, :amount, trade_amount))
        [best | _] = route

        %{
          index: index + 1,
          amount: trade_amount,
          route: best.route,
          slippage: best.slippage,
          estimated_output: best.estimated_output
        }
      end)

    total_output = Enum.reduce(trades, 0, &(&1.estimated_output + &2))
    total_slippage = Enum.reduce(trades, 0.0, &(&1.slippage + &2)) / length(trades)

    {:ok, %{
      original_amount: amount,
      num_splits: num_splits,
      trades: trades,
      total_output: total_output,
      average_slippage: total_slippage,
      savings_vs_single_trade: calculate_savings(amount, trades)
    }}
  end

  # --- Private Functions ---

  defp normalize_params(params) when is_map(params) do
    params
    |> Map.new(fn {k, v} -> {normalize_key(k), v} end)
    |> Map.put_new(:max_hops, 2)
    |> Map.put_new(:max_slippage, 0.001)
  end

  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
  defp normalize_key(key) when is_atom(key), do: key

  defp find_routes(params) do
    from = params.from
    to = params.to
    amount = params.amount
    max_hops = params.max_hops

    # Simulated route finding
    routes = [
      %{
        route: [%{from: from, to: to, pool: "direct_pool"}],
        hops: 1,
        slippage: calculate_slippage(amount, from, to, 1),
        estimated_output: amount * (1 - calculate_slippage(amount, from, to, 1)),
        price_impact: calculate_slippage(amount, from, to, 1) * 100,
        fee: amount * 0.0004,  # 0.04% Curve fee
        gas_estimate: 180_000
      }
    ]

    # Add multi-hop routes if allowed
    routes =
      if max_hops >= 2 do
        routes ++ [
          %{
            route: [
              %{from: from, to: "USDC", pool: "pool_1"},
              %{from: "USDC", to: to, pool: "pool_2"}
            ],
            hops: 2,
            slippage: calculate_slippage(amount, from, to, 2),
            estimated_output: amount * (1 - calculate_slippage(amount, from, to, 2)),
            price_impact: calculate_slippage(amount, from, to, 2) * 100,
            fee: amount * 0.0008,  # Double fee for 2 hops
            gas_estimate: 350_000
          }
        ]
      else
        routes
      end

    {:ok, Enum.sort_by(routes, & &1.slippage)}
  end

  defp select_optimal_route(routes, params) do
    max_slippage = params.max_slippage

    case Enum.find(routes, fn r -> r.slippage <= max_slippage end) do
      nil ->
        # Return best available even if exceeds max slippage
        case routes do
          [best | _] -> {:ok, best}
          [] -> {:error, :no_routes_found}
        end

      optimal ->
        {:ok, optimal}
    end
  end

  defp calculate_slippage(amount, _from, _to, hops) do
    # Simplified slippage calculation based on amount and pool depth
    base_slippage = 0.0001  # 0.01% base

    amount_factor =
      cond do
        amount < 10_000 -> 1.0
        amount < 100_000 -> 1.5
        amount < 1_000_000 -> 3.0
        true -> 5.0
      end

    hop_factor = hops * 0.5

    base_slippage * amount_factor * hop_factor
  end

  defp split_amount_evenly(total, num_splits) do
    base = floor(total / num_splits)
    remainder = rem(total, num_splits)

    Enum.map(0..(num_splits - 1), fn i ->
      base + if i < remainder, do: 1, else: 0
    end)
  end

  defp calculate_savings(_total_amount, _trades) do
    # Calculate savings from splitting vs single large trade
    0.0015  # Simulated savings of 0.15%
  end
end
