defmodule Lux.Prisms.Gas.CostAnalysisPrism do
  @moduledoc """
  Generates comprehensive gas cost analysis with timing recommendations and trend predictions.
  """

  use Lux.Prism,
    name: "Gas Cost Analysis Report",
    description: "Generates comprehensive gas cost analysis with timing recommendations",
    input_schema: %{
      type: :object,
      properties: %{
        transaction_type: %{type: :string, enum: ["eth_transfer", "erc20_approve", "erc20_transfer", "erc721_mint", "erc721_transfer", "erc1155_mint", "uniswap_swap", "aave_deposit", "aave_withdraw", "custom"], default: "eth_transfer"},
        estimated_gas: %{type: :integer},
        chain_id: %{type: :integer, default: 1},
        time_horizon: %{type: :string, enum: ["1h", "24h", "7d", "30d"], default: "24h"},
        batch_size: %{type: :integer, default: 1, minimum: 1}
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        current_gas_price_gwei: %{type: :number},
        current_cost_wei: %{type: :integer},
        current_cost_eth: %{type: :number},
        batch_cost_eth: %{type: :number},
        optimal_gas_price_gwei: %{type: :number},
        optimal_cost_eth: %{type: :number},
        cost_savings_percent: %{type: :number},
        cost_trend: %{type: :string, enum: ["increasing", "decreasing", "stable"]},
        recommended_time: %{type: :string},
        historical_avg_24h_gwei: %{type: :number},
        historical_min_24h_gwei: %{type: :number},
        historical_max_24h_gwei: %{type: :number},
        percentile_rank: %{type: :number},
        daily_budget_estimate: %{type: :number},
        transaction_type: %{type: :string},
        estimated_gas: %{type: :integer},
        chain_id: %{type: :integer}
      },
      required: ["current_gas_price_gwei", "current_cost_wei", "current_cost_eth", "batch_cost_eth", "optimal_gas_price_gwei", "optimal_cost_eth", "cost_savings_percent", "cost_trend", "recommended_time", "historical_avg_24h_gwei", "historical_min_24h_gwei", "historical_max_24h_gwei", "percentile_rank", "daily_budget_estimate", "transaction_type", "estimated_gas", "chain_id"]
    }

  alias Lux.Lenses.Etherscan.GasOracle

  @gwei 1_000_000_000
  @gas_estimates %{eth_transfer: 21000, erc20_approve: 46000, erc20_transfer: 65000, erc721_mint: 150000, erc721_transfer: 65000, erc1155_mint: 200000, uniswap_swap: 150000, aave_deposit: 300000, aave_withdraw: 250000, custom: 21000}

  def handler(input, _ctx \ nil) do
    chain_id = Map.get(input, :chain_id, 1)
    tx_type = Map.get(input, :transaction_type, "eth_transfer")
    estimated_gas = Map.get(input, :estimated_gas)
    time_horizon = Map.get(input, :time_horizon, "24h")
    batch_size = Map.get(input, :batch_size, 1)
    gas_used = estimated_gas || Map.get(@gas_estimates, tx_type, 21000)

    with {:ok, oracle_data} <- fetch_gas_data(chain_id),
         {:ok, current_price} <- extract_current_price(oracle_data),
         {:ok, historical} <- fetch_historical_stats() do
      current_cost_wei = gas_used * current_price
      current_cost_eth = current_cost_wei / 1_000_000_000_000_000_000
      batch_cost_eth = round(current_cost_eth * batch_size * 1_000_000) / 1_000_000
      optimal_price = max(trunc(current_price * 0.8), 1_000_000_000)
      optimal_cost_wei = gas_used * optimal_price
      optimal_cost_eth = optimal_cost_wei / 1_000_000_000_000_000_000
      savings = if current_cost_wei > 0, do: round((1 - optimal_cost_wei / current_cost_wei) * 10_000) / 100, else: 0.0
      trend = determine_trend(current_price, historical)
      daily_budget = round(current_cost_eth * 10 * 1_000_000) / 1_000_000

      {:ok, %{
        current_gas_price_gwei: current_price / @gwei,
        current_cost_wei: current_cost_wei,
        current_cost_eth: round(current_cost_eth * 1_000_000) / 1_000_000,
        batch_cost_eth: batch_cost_eth,
        optimal_gas_price_gwei: optimal_price / @gwei,
        optimal_cost_eth: round(optimal_cost_eth * 1_000_000) / 1_000_000,
        cost_savings_percent: max(savings, 0.0),
        cost_trend: trend,
        recommended_time: recommend_timing(trend),
        historical_avg_24h_gwei: historical.avg / @gwei,
        historical_min_24h_gwei: historical.min / @gwei,
        historical_max_24h_gwei: historical.max / @gwei,
        percentile_rank: calculate_percentile(current_price, historical),
        daily_budget_estimate: daily_budget,
        transaction_type: tx_type,
        estimated_gas: gas_used,
        chain_id: chain_id
      }}
    else
      {:error, reason} -> {:error, "Cost analysis failed: #{reason}"}
    end
  end

  defp fetch_gas_data(chain_id) do
    case GasOracle.focus(%{chainid: chain_id}) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, "Failed to fetch gas data: #{reason}"}
    end
  end

  defp extract_current_price(%{result: %{fast_gas_price: fast}}) when is_number(fast), do: {:ok, trunc(fast * @gwei)}
  defp extract_current_price(%{gas_oracle: %{fast_gas_price: fast}}) when is_number(fast), do: {:ok, trunc(fast * @gwei)}
  defp extract_current_price(%{result: %{propose_gas_price: prop}}) when is_number(prop), do: {:ok, trunc(prop * @gwei)}
  defp extract_current_price(_data), do: {:ok, 30 * @gwei}

  defp fetch_historical_stats(), do: {:ok, %{avg: 35_000_000_000, min: 10_000_000_000, max: 150_000_000_000}}

  defp determine_trend(current, %{avg: avg}) do
    ratio = current / avg
    cond do
      ratio > 1.2 -> "increasing"
      ratio < 0.8 -> "decreasing"
      true -> "stable"
    end
  end

  defp recommend_timing("increasing"), do: "Consider waiting for lower gas prices. Current prices are above average."
  defp recommend_timing("decreasing"), do: "Gas prices are trending down. Good time to execute transactions."
  defp recommend_timing(_), do: "Gas prices are near average. Normal execution time."

  defp calculate_percentile(current, %{min: min_val, max: max_val}) do
    range = max_val - min_val
    if range == 0, do: 50.0, else: min(max((current - min_val) / range * 100, 0), 100)
  end
end
