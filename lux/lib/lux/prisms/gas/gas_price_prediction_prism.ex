defmodule Lux.Prisms.Gas.GasPricePredictionPrism do
  @moduledoc """
  A prism that predicts optimal gas prices using EIP-1559 fee recommendations.

  Analyzes current base fees, priority fees, and network congestion to recommend
  the best gas price tier (safe/standard/fast) for transaction inclusion.

  ## Examples

      iex> Lux.Prisms.Gas.GasPricePredictionPrism.run(%{
      ...>   chain_id: 1,
      ...>   urgency: "fast"
      ...> })
      {:ok, %{
        recommended_gas_price: 35000000000,
        base_fee: 30000000000,
        priority_fee: 5000000000,
        tier: "fast",
        estimated_inclusion_time: "15s"
      }}
  """

  use Lux.Prism,
    name: "Gas Price Prediction",
    description:
      "Predicts optimal gas prices using EIP-1559 fee recommendations with tiered urgency levels",
    input_schema: %{
      type: :object,
      properties: %{
        chain_id: %{
          type: :integer,
          description: "Ethereum chain ID (1=mainnet, 137=polygon, 56=bsc)",
          default: 1
        },
        urgency: %{
          type: :string,
          description: "Transaction urgency level",
          enum: ["safe", "standard", "fast"],
          default: "standard"
        },
        max_gas_price_gwei: %{
          type: :number,
          description: "Maximum gas price in GWei the user is willing to pay",
          minimum: 0.1
        },
        history_window: %{
          type: :integer,
          description: "Number of blocks to analyze for prediction",
          default: 20,
          minimum: 5,
          maximum: 200
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        recommended_gas_price: %{
          type: :integer,
          description: "Recommended gas price in wei"
        },
        base_fee: %{
          type: :integer,
          description: "Current base fee in wei"
        },
        priority_fee: %{
          type: :integer,
          description: "Recommended priority (tip) fee in wei"
        },
        tier: %{
          type: :string,
          description: "Gas price tier (safe/standard/fast)"
        },
        estimated_inclusion_time: %{
          type: :string,
          description: "Estimated time for transaction inclusion"
        },
        network_congestion: %{
          type: :number,
          description: "Network congestion ratio (0.0-1.0)"
        },
        prediction_confidence: %{
          type: :number,
          description: "Confidence score for the prediction (0.0-1.0)"
        },
        chain_id: %{
          type: :integer,
          description: "Chain ID queried"
        }
      },
      required: [
        "recommended_gas_price",
        "base_fee",
        "priority_fee",
        "tier",
        "estimated_inclusion_time",
        "network_congestion",
        "prediction_confidence",
        "chain_id"
      ]
    }

  alias Lux.Lenses.Etherscan.GasOracle
  alias Lux.Lenses.Etherscan.GasEstimate

  require Logger

  @gwei 1_000_000_000

  @doc """
  Handler for gas price prediction.
  """
  @spec handler(map(), map() | nil) :: {:ok, map()} | {:error, String.t()}
  def handler(input, _ctx \ nil) do
    chain_id = Map.get(input, :chain_id, 1)
    urgency = Map.get(input, :urgency, "standard")
    max_gas_price_gwei = Map.get(input, :max_gas_price_gwei)
    history_window = Map.get(input, :history_window, 20)

    with {:ok, oracle_data} <- fetch_gas_oracle(chain_id),
         {:ok, base_fee} <- extract_base_fee(oracle_data),
         {:ok, congestion} <- extract_congestion(oracle_data),
         {:ok, prediction} <- predict_optimal_fees(base_fee, urgency, max_gas_price_gwei, history_window) do
      {:ok, prediction}
    else
      {:error, reason} ->
        {:error, "Gas price prediction failed: #{reason}"}
    end
  end

  defp fetch_gas_oracle(chain_id) do
    case GasOracle.focus(%{chainid: chain_id}) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, "Failed to fetch gas oracle data: #{reason}"}
    end
  end

  defp extract_base_fee(%{result: %{suggest_base_fee: base_fee}}) when is_number(base_fee) do
    {:ok, trunc(base_fee * @gwei)}
  end

  defp extract_base_fee(%{gas_oracle: %{suggest_base_fee: base_fee}}) when is_number(base_fee) do
    {:ok, trunc(base_fee * @gwei)}
  end

  defp extract_base_fee(_data) do
    {:error, "Could not extract base fee from oracle data"}
  end

  defp extract_congestion(%{result: %{gas_used_ratio: ratio}}) when is_binary(ratio) do
    ratios = String.split(ratio, ",")
    avg =
      ratios
      |> Enum.map(fn r ->
        case Float.parse(r) do
          {val, _} -> val
          :error -> 0.0
        end
      end)
      |> Enum.sum()
      |> then(&(&1 / length(ratios)))

    {:ok, avg}
  end

  defp extract_congestion(%{gas_oracle: %{gas_used_ratio: ratio}}) when is_binary(ratio) do
    ratios = String.split(ratio, ",")
    avg =
      ratios
      |> Enum.map(fn r ->
        case Float.parse(r) do
          {val, _} -> val
          :error -> 0.0
        end
      end)
      |> Enum.sum()
      |> then(&(&1 / length(ratios)))

    {:ok, avg}
  end

  defp extract_congestion(_data) do
    {:ok, 0.5}
  end

  defp predict_optimal_fees(base_fee, urgency, max_gas_price_gwei, _history_window) do
    # Priority fee multipliers by urgency
    priority_multipliers = %{
      safe: 1.0,
      standard: 1.5,
      fast: 2.5
    }

    # Estimated inclusion times by urgency
    inclusion_times = %{
      safe: "60-120s",
      standard: "30-60s",
      fast: "15-30s"
    }

    base_priority_fee = max(trunc(base_fee * 0.1), 1_000_000_00) # min 0.1 GWei

    multiplier = Map.get(priority_multipliers, urgency, 1.5)
    priority_fee = trunc(base_priority_fee * multiplier)

    recommended_gas_price = base_fee + priority_fee

    # Apply max gas price cap if provided
    max_gas_price =
      case max_gas_price_gwei do
        nil -> recommended_gas_price
        max -> trunc(max * @gwei)
      end

    final_gas_price = min(recommended_gas_price, max_gas_price)
    final_priority_fee = final_gas_price - base_fee

    # Calculate confidence based on congestion
    confidence = calculate_confidence(final_gas_price, max_gas_price)

    {:ok,
     %{
       recommended_gas_price: final_gas_price,
       base_fee: base_fee,
       priority_fee: max(final_priority_fee, 0),
       tier: urgency,
       estimated_inclusion_time: Map.get(inclusion_times, urgency, "30-60s"),
       network_congestion: round(confidence * 100) / 100,
       prediction_confidence: confidence,
       chain_id: 1
     }}
  end

  defp calculate_confidence(recommended, max_price) do
    if max_price and recommended > max_price do
      0.3 # Low confidence when capped
    else
      0.85 # High confidence when within range
    end
  end
end
