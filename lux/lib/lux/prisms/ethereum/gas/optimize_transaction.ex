defmodule Lux.Prisms.Ethereum.Gas.OptimizeTransaction do
  @moduledoc """
  A prism for optimizing Ethereum transaction gas parameters.

  Fetches live gas oracle data and recommends optimal maxFeePerGas,
  maxPriorityFeePerGas (EIP-1559), and legacy gasPrice based on
  urgency level. Also calculates estimated transaction cost in USD.

  ## Examples

      iex> OptimizeTransaction.handler(%{
      ...>   urgency: :standard,
      ...>   gas_limit: 21_000
      ...> }, %{name: "TradingAgent"})
      {:ok, %{
        max_fee_per_gas_gwei: 25.3,
        max_priority_fee_gwei: 1.5,
        estimated_cost_gwei: 442_000,
        urgency: :standard
      }}
  """

  use Lux.Prism,
    name: "Optimize Ethereum Gas",
    description: "Recommends optimal EIP-1559 gas parameters for a transaction based on urgency",
    input_schema: %{
      type: :object,
      properties: %{
        urgency: %{
          type: :string,
          description: "Transaction urgency level",
          enum: ["slow", "standard", "fast"],
          default: "standard"
        },
        gas_limit: %{
          type: :integer,
          description: "Estimated gas units the transaction will consume",
          default: 21_000
        },
        eth_price_usd: %{
          type: :number,
          description: "Current ETH price in USD for cost estimation",
          default: 0.0
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        max_fee_per_gas_gwei: %{type: :number, description: "Recommended maxFeePerGas in gwei (EIP-1559)"},
        max_priority_fee_gwei: %{type: :number, description: "Recommended maxPriorityFeePerGas in gwei"},
        legacy_gas_price_gwei: %{type: :number, description: "Legacy gasPrice for non-EIP1559 transactions"},
        estimated_cost_gwei: %{type: :integer, description: "Total estimated gas cost in gwei units"},
        estimated_cost_usd: %{type: :number, description: "Estimated cost in USD (0 if eth_price_usd not provided)"},
        base_fee_gwei: %{type: :number, description: "Current base fee per gas in gwei"},
        urgency: %{type: :string},
        network_congestion: %{type: :string, description: "low | medium | high"}
      },
      required: ["max_fee_per_gas_gwei", "urgency"]
    }

  alias Lux.Lenses.Etherscan.GasOracle
  require Logger

  @priority_fees %{
    "slow"     => 1.0,
    "standard" => 1.5,
    "fast"     => 3.0
  }

  @impl true
  def handler(params, agent) do
    urgency    = Map.get(params, :urgency, "standard")
    gas_limit  = Map.get(params, :gas_limit, 21_000)
    eth_price  = Map.get(params, :eth_price_usd, 0.0)
    agent_name = agent[:name] || "Unknown"

    Logger.info("Agent #{agent_name} optimizing gas for urgency=#{urgency}")

    case GasOracle.focus(%{}) do
      {:ok, %{gas_oracle: oracle}} ->
        base_fee      = oracle.suggest_base_fee || 20.0
        gas_used_ratio = parse_avg_ratio(oracle.gas_used_ratio)
        congestion    = classify_congestion(gas_used_ratio)

        priority_fee = @priority_fees[urgency] || 1.5
        # EIP-1559: maxFeePerGas = 2 * baseFee + priorityFee
        max_fee      = Float.round(2 * base_fee + priority_fee, 4)

        legacy_price = case urgency do
          "slow"     -> oracle.safe_gas_price
          "fast"     -> oracle.fast_gas_price
          _          -> oracle.propose_gas_price
        end

        cost_gwei    = round(max_fee * gas_limit)
        cost_eth     = cost_gwei / 1.0e9
        cost_usd     = if eth_price > 0, do: Float.round(cost_eth * eth_price, 6), else: 0.0

        Logger.info("Gas optimized: max_fee=#{max_fee} gwei, congestion=#{congestion}")
        {:ok, %{
          max_fee_per_gas_gwei:   max_fee,
          max_priority_fee_gwei:  priority_fee,
          legacy_gas_price_gwei:  legacy_price,
          estimated_cost_gwei:    cost_gwei,
          estimated_cost_usd:     cost_usd,
          base_fee_gwei:          base_fee,
          urgency:                urgency,
          network_congestion:     congestion
        }}

      {:error, reason} ->
        Logger.error("Gas oracle fetch failed: #{inspect(reason)}")
        {:error, "Failed to fetch gas oracle: #{inspect(reason)}"}
    end
  end

  defp parse_avg_ratio(ratio_str) when is_binary(ratio_str) do
    ratio_str
    |> String.split(",")
    |> Enum.map(fn s ->
      case Float.parse(String.trim(s)) do
        {f, _} -> f
        :error  -> 0.5
      end
    end)
    |> then(fn vals -> Enum.sum(vals) / max(length(vals), 1) end)
  end
  defp parse_avg_ratio(_), do: 0.5

  defp classify_congestion(ratio) when ratio > 0.8, do: "high"
  defp classify_congestion(ratio) when ratio > 0.5, do: "medium"
  defp classify_congestion(_), do: "low"
end
