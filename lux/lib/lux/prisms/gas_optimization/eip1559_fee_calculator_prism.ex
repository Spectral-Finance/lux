defmodule Lux.Prisms.GasOptimization.EIP1559FeeCalculatorPrism do
  @moduledoc """
  A prism that calculates EIP-1559 compliant fee parameters.

  Implements the EIP-1559 fee market mechanism with base fee prediction,
  priority fee optimization, and fee bumping for transaction replacement.

  Supports:
  - Base fee prediction using block utilization history
  - Priority fee calculation for different urgency levels
  - Fee bumping for stuck transaction replacement (speed up / cancel)
  - Multi-block base fee forecasting

  ## Examples

      iex> Lux.Prisms.GasOptimization.EIP1559FeeCalculatorPrism.run(%{
      ...>   action: "calculate",
      ...>   urgency: "medium"
      ...> })
      {:ok, %{
        base_fee_gwei: 20.5,
        max_priority_fee_gwei: 2.0,
        max_fee_per_gas_gwei: 43.0,
        predicted_base_fees: [20.5, 21.0, 22.3],
        fee_savings_vs_legacy_pct: 15.2
      }}
  """

  use Lux.Prism,
    name: "EIP-1559 Fee Calculator",
    description: "Calculates optimal EIP-1559 transaction fees with base fee prediction and fee bumping",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["calculate", "bump", "predict"],
          description: "Action: calculate fees, bump existing tx, or predict future fees",
          default: "calculate"
        },
        urgency: %{
          type: :string,
          enum: ["low", "medium", "high", "urgent"],
          description: "Transaction urgency level",
          default: "medium"
        },
        current_base_fee_gwei: %{
          type: :number,
          description: "Current base fee in Gwei (auto-fetched if not provided)"
        },
        gas_used_ratios: %{
          type: :string,
          description: "Comma-separated gas utilization ratios for recent blocks"
        },
        original_max_fee_gwei: %{
          type: :number,
          description: "Original max fee for bump action"
        },
        original_priority_fee_gwei: %{
          type: :number,
          description: "Original priority fee for bump action"
        },
        prediction_blocks: %{
          type: :integer,
          description: "Number of future blocks to predict",
          default: 5
        },
        network: %{
          type: :string,
          enum: ["mainnet", "goerli", "sepolia"],
          default: "mainnet"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        base_fee_gwei: %{type: :number},
        max_priority_fee_gwei: %{type: :number},
        max_fee_per_gas_gwei: %{type: :number},
        predicted_base_fees: %{type: :array, description: "Predicted base fees for upcoming blocks"},
        fee_savings_vs_legacy_pct: %{type: :number, description: "Savings vs legacy gas pricing"}
      }
    }

  require Logger

  # EIP-1559 constants
  @base_fee_change_denominator 8
  @elasticity_multiplier 2
  @target_gas_used 15_000_000
  @max_gas_used 30_000_000

  # Priority fee percentiles by urgency
  @urgency_priority_fees %{
    "low" => 1.0,
    "medium" => 2.0,
    "high" => 3.5,
    "urgent" => 5.0
  }

  # Min bump percentage per EIP-1559 spec (10%)
  @min_bump_percentage 0.10

  def handler(input, _ctx) do
    action = Map.get(input, :action, "calculate")
    urgency = Map.get(input, :urgency, "medium")
    network = Map.get(input, :network, "mainnet")

    case action do
      "calculate" -> calculate_fees(input, urgency, network)
      "bump" -> bump_fees(input)
      "predict" -> predict_fees(input, network)
    end
  end

  @doc """
  Calculates optimal EIP-1559 fee parameters.
  """
  def calculate_fees(input, urgency, network) do
    with {:ok, base_fee, ratios} <- get_network_data(input, network) do
      priority_fee = Map.get(@urgency_priority_fees, urgency, 2.0)

      # Predict next block's base fee
      predicted_base = predict_next_base_fee(base_fee, ratios)

      # Max fee = 2 * predicted_base + priority (ensures inclusion for 2+ blocks)
      max_fee = predicted_base * 2 + priority_fee

      # Compare with legacy pricing
      legacy_price = base_fee + priority_fee * 2
      savings_pct =
        if legacy_price > 0,
          do: Float.round((1 - max_fee / legacy_price) * 100, 1),
          else: 0.0

      {:ok,
       %{
         base_fee_gwei: Float.round(base_fee, 4),
         max_priority_fee_gwei: Float.round(priority_fee, 4),
         max_fee_per_gas_gwei: Float.round(max_fee, 4),
         predicted_next_base_fee_gwei: Float.round(predicted_base, 4),
         fee_savings_vs_legacy_pct: savings_pct,
         urgency: urgency,
         network: network
       }}
    end
  end

  @doc """
  Bumps fees for transaction replacement (speed up or cancel).
  Per EIP-1559, both maxFeePerGas and maxPriorityFeePerGas must
  increase by at least 10%.
  """
  def bump_fees(input) do
    original_max = Map.get(input, :original_max_fee_gwei)
    original_priority = Map.get(input, :original_priority_fee_gwei)

    if is_nil(original_max) or is_nil(original_priority) do
      {:error, "bump action requires original_max_fee_gwei and original_priority_fee_gwei"}
    else
      bump_factor = 1 + @min_bump_percentage

      bumped_max = original_max * bump_factor
      bumped_priority = original_priority * bump_factor

      {:ok,
       %{
         original_max_fee_gwei: original_max,
         original_priority_fee_gwei: original_priority,
         bumped_max_fee_gwei: Float.round(bumped_max, 4),
         bumped_priority_fee_gwei: Float.round(bumped_priority, 4),
         bump_percentage: Float.round(@min_bump_percentage * 100, 1),
         action: "bump"
       }}
    end
  end

  @doc """
  Predicts base fees for upcoming blocks using the EIP-1559 formula.
  """
  def predict_fees(input, network) do
    blocks = Map.get(input, :prediction_blocks, 5)

    with {:ok, base_fee, ratios} <- get_network_data(input, network) do
      predictions = predict_multiple_blocks(base_fee, ratios, blocks)

      {:ok,
       %{
         current_base_fee_gwei: Float.round(base_fee, 4),
         predicted_base_fees: Enum.map(predictions, &Float.round(&1, 4)),
         prediction_blocks: blocks,
         trend: calculate_trend(predictions),
         network: network
       }}
    end
  end

  @doc """
  Predicts the next block's base fee using the EIP-1559 algorithm.

  The formula:
  - If gas_used == target: base_fee stays the same
  - If gas_used > target: base_fee increases proportionally (up to 12.5%)
  - If gas_used < target: base_fee decreases proportionally (up to 12.5%)
  """
  def predict_next_base_fee(current_base_fee, ratios) when is_list(ratios) do
    # Use the most recent ratio
    latest_ratio = List.last(ratios) || 0.5
    predict_base_fee_from_ratio(current_base_fee, latest_ratio)
  end

  def predict_next_base_fee(current_base_fee, _), do: current_base_fee

  @doc """
  Calculates next base fee from a single gas utilization ratio.
  """
  def predict_base_fee_from_ratio(base_fee, ratio) when is_number(ratio) do
    gas_used = ratio * @max_gas_used

    cond do
      gas_used > @target_gas_used ->
        # Base fee increases
        gas_delta = gas_used - @target_gas_used
        fee_delta = base_fee * gas_delta / @target_gas_used / @base_fee_change_denominator
        base_fee + max(fee_delta, 1.0)

      gas_used < @target_gas_used ->
        # Base fee decreases
        gas_delta = @target_gas_used - gas_used
        fee_delta = base_fee * gas_delta / @target_gas_used / @base_fee_change_denominator
        max(base_fee - fee_delta, 1.0)

      true ->
        base_fee
    end
  end

  defp predict_multiple_blocks(base_fee, ratios, count) do
    parsed_ratios = parse_ratios(ratios)
    avg_ratio = if Enum.empty?(parsed_ratios), do: 0.5, else: Enum.sum(parsed_ratios) / length(parsed_ratios)

    Enum.reduce(1..count, {base_fee, []}, fn _i, {current_fee, predictions} ->
      next_fee = predict_base_fee_from_ratio(current_fee, avg_ratio)
      {next_fee, predictions ++ [next_fee]}
    end)
    |> elem(1)
  end

  defp calculate_trend(predictions) when length(predictions) < 2, do: "stable"

  defp calculate_trend(predictions) do
    first = List.first(predictions)
    last = List.last(predictions)

    change_pct = if first > 0, do: (last - first) / first * 100, else: 0

    cond do
      change_pct > 5 -> "increasing"
      change_pct < -5 -> "decreasing"
      true -> "stable"
    end
  end

  defp get_network_data(input, network) do
    base_fee = Map.get(input, :current_base_fee_gwei)
    raw_ratios = Map.get(input, :gas_used_ratios)

    if base_fee do
      {:ok, base_fee, parse_ratios(raw_ratios)}
    else
      case Lux.Lenses.Etherscan.GasOracle.focus(%{chainid: chain_id(network)}) do
        {:ok, %{gas_oracle: oracle}} ->
          parsed_base = parse_number(oracle.suggest_base_fee, 20.0)
          parsed_ratios = parse_ratios(oracle.gas_used_ratio)
          {:ok, parsed_base, parsed_ratios}

        {:error, reason} ->
          {:error, "Failed to fetch network data: #{inspect(reason)}"}
      end
    end
  end

  defp parse_ratios(nil), do: [0.5]

  defp parse_ratios(ratios) when is_binary(ratios) do
    ratios
    |> String.split(",")
    |> Enum.map(fn r ->
      case Float.parse(String.trim(r)) do
        {val, _} -> val
        :error -> 0.5
      end
    end)
  end

  defp parse_ratios(ratios) when is_list(ratios), do: ratios
  defp parse_ratios(_), do: [0.5]

  defp parse_number(value, _default) when is_number(value), do: value * 1.0

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
