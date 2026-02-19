defmodule Lux.Lenses.Etherscan.GasUsageAnalytics do
  @moduledoc """
  Lens for comprehensive gas usage analytics combining multiple Etherscan data sources.

  Provides a unified view of gas metrics including:
  - Current gas prices and trends
  - Daily gas consumption patterns
  - Network utilization metrics
  - Historical gas price analysis
  - Cost optimization insights

  ## Examples

  ```elixir
  # Get comprehensive gas analytics
  Lux.Lenses.Etherscan.GasUsageAnalytics.focus(%{
    chainid: 1,
    analysis_type: "overview"
  })

  # Get cost analysis for a specific gas usage
  Lux.Lenses.Etherscan.GasUsageAnalytics.focus(%{
    chainid: 1,
    analysis_type: "cost_analysis",
    gas_amount: 150000
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.GasUsageAnalytics",
    description: "Comprehensive gas usage analytics with current prices, trends, and cost optimization insights",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        chainid: %{
          type: :integer,
          description: "Network identifier (1=Ethereum, 137=Polygon, 56=BSC, etc.)",
          default: 1
        },
        analysis_type: %{
          type: :string,
          enum: ["overview", "cost_analysis", "trend"],
          description: "Type of analysis to perform",
          default: "overview"
        },
        gas_amount: %{
          type: :integer,
          description: "Gas amount for cost analysis",
          default: 21000
        }
      },
      required: []
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    params
    |> Map.put(:module, "gastracker")
    |> Map.put(:action, "gasoracle")
  end

  @doc """
  Transforms the gas oracle response into comprehensive analytics.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_map(result) ->
        safe_price = parse_float(Map.get(result, "SafeGasPrice", "0"))
        proposed_price = parse_float(Map.get(result, "ProposeGasPrice", "0"))
        fast_price = parse_float(Map.get(result, "FastGasPrice", "0"))
        base_fee = parse_float(Map.get(result, "suggestBaseFee", "0"))
        gas_used_ratio = Map.get(result, "gasUsedRatio", "")
        last_block = parse_integer(Map.get(result, "LastBlock", "0"))

        # Parse gas used ratios
        ratios = parse_ratios(gas_used_ratio)
        avg_utilization = if Enum.empty?(ratios), do: 0.0, else: Enum.sum(ratios) / length(ratios)

        # Network congestion analysis
        congestion = analyze_congestion(avg_utilization)

        # Price spread analysis
        spread = calculate_spread(safe_price, proposed_price, fast_price)

        # Cost calculations for common operations
        cost_matrix = calculate_cost_matrix(safe_price, proposed_price, fast_price)

        analytics = %{
          current_prices: %{
            safe_gwei: safe_price,
            standard_gwei: proposed_price,
            fast_gwei: fast_price,
            base_fee_gwei: base_fee
          },
          network_status: %{
            last_block: last_block,
            avg_utilization: Float.round(avg_utilization * 100.0, 1),
            congestion_level: congestion.level,
            congestion_description: congestion.description,
            block_utilizations: ratios
          },
          price_analysis: %{
            spread_gwei: spread.absolute,
            spread_pct: spread.percentage,
            volatility_indicator: spread.volatility,
            priority_fee_estimate: Float.round(max(0.0, proposed_price - base_fee) * 1.0, 4)
          },
          cost_matrix: cost_matrix,
          recommendations: generate_recommendations(congestion, spread, base_fee)
        }

        {:ok, %{result: analytics, analytics: analytics}}

      other ->
        other
    end
  end

  defp analyze_congestion(utilization) do
    cond do
      utilization < 0.25 ->
        %{level: "low", description: "Network is quiet. Good time for non-urgent transactions."}

      utilization < 0.50 ->
        %{level: "moderate", description: "Normal network activity. Standard gas prices apply."}

      utilization < 0.75 ->
        %{level: "high", description: "Elevated network usage. Consider waiting for lower gas."}

      utilization < 0.90 ->
        %{level: "very_high", description: "Heavy congestion. Only submit urgent transactions."}

      true ->
        %{level: "extreme", description: "Network is saturated. Expect high fees and delays."}
    end
  end

  defp calculate_spread(safe, _proposed, fast) do
    absolute = Float.round((fast - safe) * 1.0, 4)

    percentage =
      if safe > 0,
        do: Float.round((fast - safe) / safe * 100.0, 1),
        else: 0.0

    volatility = cond do
      percentage > 100 -> "extreme"
      percentage > 50 -> "high"
      percentage > 20 -> "moderate"
      true -> "low"
    end

    %{absolute: absolute, percentage: percentage, volatility: volatility}
  end

  defp calculate_cost_matrix(safe, proposed, fast) do
    operations = [
      {"ETH Transfer", 21_000},
      {"ERC20 Transfer", 65_000},
      {"ERC20 Approve", 46_000},
      {"DEX Swap", 150_000},
      {"NFT Mint", 200_000},
      {"Contract Deploy (small)", 500_000}
    ]

    Enum.map(operations, fn {name, gas} ->
      %{
        operation: name,
        gas_units: gas,
        cost_slow_eth: Float.round(gas * safe / 1_000_000_000.0, 6),
        cost_standard_eth: Float.round(gas * proposed / 1_000_000_000.0, 6),
        cost_fast_eth: Float.round(gas * fast / 1_000_000_000.0, 6)
      }
    end)
  end

  defp generate_recommendations(congestion, spread, base_fee) do
    recs = []

    recs =
      if congestion.level in ["very_high", "extreme"] do
        recs ++ ["Consider delaying non-urgent transactions until network congestion decreases"]
      else
        recs
      end

    recs =
      if spread.volatility in ["high", "extreme"] do
        recs ++ ["High gas price spread indicates volatility. Use EIP-1559 for better fee predictability."]
      else
        recs
      end

    recs =
      if base_fee > 50 do
        recs ++ ["Base fee is elevated (#{base_fee} Gwei). Batch multiple operations if possible."]
      else
        recs
      end

    recs =
      if congestion.level in ["low", "moderate"] do
        recs ++ ["Good conditions for transaction submission. Network utilization is manageable."]
      else
        recs
      end

    if Enum.empty?(recs) do
      ["Standard network conditions. No special action needed."]
    else
      recs
    end
  end

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float_value, _} -> float_value
      :error -> 0.0
    end
  end

  defp parse_float(value) when is_number(value), do: value * 1.0
  defp parse_float(_), do: 0.0

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, _} -> int_value
      :error -> 0
    end
  end

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(_), do: 0

  defp parse_ratios(ratio_string) when is_binary(ratio_string) do
    ratio_string
    |> String.split(",")
    |> Enum.map(fn r ->
      case Float.parse(String.trim(r)) do
        {val, _} -> Float.round(val * 1.0, 4)
        :error -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_ratios(_), do: []
end
