defmodule Lux.Prisms.GasOptimization.GasPriceEstimatorPrism do
  @moduledoc """
  A prism that estimates optimal gas prices for Ethereum transactions.

  Uses historical gas data and current network conditions to predict
  gas prices across different urgency levels (slow, standard, fast, instant).

  Supports both legacy gas pricing and EIP-1559 fee model.

  ## Examples

      iex> Lux.Prisms.GasOptimization.GasPriceEstimatorPrism.run(%{
      ...>   strategy: "standard",
      ...>   network: "mainnet"
      ...> })
      {:ok, %{
        strategy: "standard",
        legacy: %{gas_price_gwei: 25.0},
        eip1559: %{max_fee_per_gas_gwei: 30.0, max_priority_fee_per_gas_gwei: 2.0, base_fee_gwei: 20.0},
        estimated_wait_seconds: 30,
        confidence: 0.85,
        network: "mainnet"
      }}
  """

  use Lux.Prism,
    name: "Gas Price Estimator",
    description: "Estimates optimal gas prices using network conditions and historical data",
    input_schema: %{
      type: :object,
      properties: %{
        strategy: %{
          type: :string,
          enum: ["slow", "standard", "fast", "instant"],
          description: "Gas pricing strategy based on urgency",
          default: "standard"
        },
        network: %{
          type: :string,
          enum: ["mainnet", "goerli", "sepolia"],
          description: "Ethereum network",
          default: "mainnet"
        },
        gas_limit: %{
          type: :integer,
          description: "Gas limit for cost estimation",
          default: 21000
        },
        max_fee_cap_gwei: %{
          type: :number,
          description: "Maximum acceptable fee in Gwei (optional safety cap)"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        strategy: %{type: :string, description: "Selected gas strategy"},
        legacy: %{
          type: :object,
          properties: %{
            gas_price_gwei: %{type: :number, description: "Recommended gas price in Gwei"}
          }
        },
        eip1559: %{
          type: :object,
          properties: %{
            max_fee_per_gas_gwei: %{type: :number, description: "Max fee per gas in Gwei"},
            max_priority_fee_per_gas_gwei: %{type: :number, description: "Max priority fee in Gwei"},
            base_fee_gwei: %{type: :number, description: "Current base fee in Gwei"}
          }
        },
        estimated_wait_seconds: %{type: :integer, description: "Estimated confirmation time"},
        estimated_cost_eth: %{type: :number, description: "Estimated transaction cost in ETH"},
        confidence: %{type: :number, description: "Confidence score 0-1"},
        network: %{type: :string, description: "Network used"}
      },
      required: ["strategy", "legacy", "eip1559", "estimated_wait_seconds", "confidence"]
    }

  require Logger

  @strategy_multipliers %{
    "slow" => %{priority: 0.8, base: 1.0, wait: 120, confidence: 0.7},
    "standard" => %{priority: 1.0, base: 1.1, wait: 30, confidence: 0.85},
    "fast" => %{priority: 1.5, base: 1.25, wait: 15, confidence: 0.90},
    "instant" => %{priority: 2.0, base: 1.5, wait: 6, confidence: 0.95}
  }

  def handler(input, _ctx) do
    strategy = Map.get(input, :strategy, "standard")
    network = Map.get(input, :network, "mainnet")
    gas_limit = Map.get(input, :gas_limit, 21_000)
    max_fee_cap = Map.get(input, :max_fee_cap_gwei)

    with {:ok, oracle_data} <- fetch_gas_oracle(network),
         {:ok, estimation} <- calculate_estimation(oracle_data, strategy, gas_limit, max_fee_cap) do
      {:ok, Map.put(estimation, :network, network)}
    else
      {:error, reason} ->
        Logger.warning("Gas price estimation failed: #{inspect(reason)}")
        {:error, "Gas estimation failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Fetches current gas oracle data from the network.
  Returns base fee, priority fees at different levels, and gas used ratios.
  """
  def fetch_gas_oracle(network) do
    case Lux.Lenses.Etherscan.GasOracle.focus(%{chainid: chain_id(network)}) do
      {:ok, %{gas_oracle: oracle}} ->
        {:ok, oracle}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Calculates gas price estimation based on oracle data and strategy.
  """
  def calculate_estimation(oracle_data, strategy, gas_limit, max_fee_cap) do
    multipliers = Map.get(@strategy_multipliers, strategy, @strategy_multipliers["standard"])

    base_fee = parse_number(oracle_data.suggest_base_fee, 20.0)
    safe_price = parse_number(oracle_data.safe_gas_price, 15.0)
    proposed_price = parse_number(oracle_data.propose_gas_price, 20.0)
    fast_price = parse_number(oracle_data.fast_gas_price, 30.0)

    # Calculate priority fee based on strategy
    priority_fee = calculate_priority_fee(safe_price, proposed_price, fast_price, strategy)
    adjusted_priority = priority_fee * multipliers.priority

    # Calculate max fee (base fee * buffer + priority fee)
    max_fee = base_fee * multipliers.base + adjusted_priority

    # Apply fee cap if specified
    {final_max_fee, final_priority} = apply_fee_cap(max_fee, adjusted_priority, max_fee_cap)

    # Legacy gas price
    legacy_price = calculate_legacy_price(safe_price, proposed_price, fast_price, strategy)

    # Estimated cost
    cost_eth = final_max_fee * gas_limit / 1_000_000_000.0

    # Confidence based on gas used ratio
    congestion = parse_congestion(oracle_data.gas_used_ratio)
    adjusted_confidence = adjust_confidence(multipliers.confidence, congestion)

    estimation = %{
      strategy: strategy,
      legacy: %{
        gas_price_gwei: Float.round(legacy_price, 4)
      },
      eip1559: %{
        max_fee_per_gas_gwei: Float.round(final_max_fee, 4),
        max_priority_fee_per_gas_gwei: Float.round(final_priority, 4),
        base_fee_gwei: Float.round(base_fee, 4)
      },
      estimated_wait_seconds: multipliers.wait,
      estimated_cost_eth: Float.round(cost_eth, 8),
      confidence: Float.round(adjusted_confidence, 2),
      congestion_level: categorize_congestion(congestion),
      gas_limit: gas_limit
    }

    {:ok, estimation}
  end

  defp calculate_priority_fee(safe, proposed, fast, strategy) do
    case strategy do
      "slow" -> safe * 0.1
      "standard" -> proposed * 0.1
      "fast" -> (fast - proposed) * 0.5 + proposed * 0.1
      "instant" -> fast * 0.15
    end
  end

  defp calculate_legacy_price(safe, proposed, fast, strategy) do
    case strategy do
      "slow" -> safe
      "standard" -> proposed
      "fast" -> fast
      "instant" -> fast * 1.2
    end
  end

  defp apply_fee_cap(max_fee, priority, nil), do: {max_fee, priority}

  defp apply_fee_cap(max_fee, priority, cap) when is_number(cap) do
    if max_fee > cap do
      capped_priority = min(priority, cap * 0.2)
      {cap, capped_priority}
    else
      {max_fee, priority}
    end
  end

  defp parse_congestion(ratio) when is_binary(ratio) do
    ratio
    |> String.split(",")
    |> Enum.map(fn r ->
      case Float.parse(String.trim(r)) do
        {val, _} -> val
        :error -> 0.5
      end
    end)
    |> then(fn values ->
      if Enum.empty?(values), do: 0.5, else: Enum.sum(values) / length(values)
    end)
  end

  defp parse_congestion(_), do: 0.5

  defp adjust_confidence(base_confidence, congestion) do
    # Higher congestion = lower confidence in timing estimates
    penalty = max(0, (congestion - 0.5) * 0.3)
    max(0.3, base_confidence - penalty)
  end

  defp categorize_congestion(congestion) when congestion < 0.3, do: "low"
  defp categorize_congestion(congestion) when congestion < 0.6, do: "moderate"
  defp categorize_congestion(congestion) when congestion < 0.85, do: "high"
  defp categorize_congestion(_), do: "very_high"

  defp parse_number(value, default) when is_number(value), do: value * 1.0

  defp parse_number(value, default) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> default
    end
  end

  defp parse_number(_, default), do: default

  defp chain_id("mainnet"), do: 1
  defp chain_id("goerli"), do: 5
  defp chain_id("sepolia"), do: 11_155_111
  defp chain_id(_), do: 1
end
