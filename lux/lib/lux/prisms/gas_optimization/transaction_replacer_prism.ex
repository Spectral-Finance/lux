defmodule Lux.Prisms.GasOptimization.TransactionReplacerPrism do
  @moduledoc """
  A prism for replacing pending transactions (speed up or cancel).

  Implements EIP-1559 compliant transaction replacement by creating
  replacement transactions with appropriately bumped gas parameters.

  ## Replacement Types

  - **Speed Up**: Creates a replacement with higher gas fees but same data
  - **Cancel**: Creates a zero-value self-transfer with higher gas fees
  - **Replace**: Creates a replacement with different data/value and higher gas fees

  ## Examples

      iex> Lux.Prisms.GasOptimization.TransactionReplacerPrism.run(%{
      ...>   action: "speed_up",
      ...>   original_tx: %{
      ...>     nonce: 42,
      ...>     to: "0xabc...",
      ...>     value: "1000000000000000000",
      ...>     max_fee_per_gas_gwei: 20.0,
      ...>     max_priority_fee_per_gas_gwei: 2.0,
      ...>     gas_limit: 21000
      ...>   },
      ...>   from: "0x1234..."
      ...> })
      {:ok, %{
        replacement_tx: %{...},
        fee_increase_pct: 12.5,
        action: "speed_up"
      }}
  """

  use Lux.Prism,
    name: "Transaction Replacer",
    description: "Creates replacement transactions for speeding up or cancelling pending transactions",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["speed_up", "cancel", "replace"],
          description: "Replacement action type"
        },
        original_tx: %{
          type: :object,
          description: "Original transaction parameters",
          properties: %{
            nonce: %{type: :integer, description: "Transaction nonce"},
            to: %{type: :string, description: "Destination address"},
            value: %{type: :string, description: "Value in wei"},
            data: %{type: :string, description: "Calldata hex"},
            max_fee_per_gas_gwei: %{type: :number},
            max_priority_fee_per_gas_gwei: %{type: :number},
            gas_limit: %{type: :integer}
          },
          required: ["nonce", "max_fee_per_gas_gwei", "max_priority_fee_per_gas_gwei"]
        },
        from: %{
          type: :string,
          description: "Sender address"
        },
        bump_percentage: %{
          type: :number,
          description: "Fee bump percentage (minimum 10% per spec)",
          default: 12.5
        },
        new_to: %{type: :string, description: "New destination (for replace action)"},
        new_value: %{type: :string, description: "New value in wei (for replace action)"},
        new_data: %{type: :string, description: "New calldata (for replace action)"}
      },
      required: ["action", "original_tx", "from"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        replacement_tx: %{type: :object, description: "Replacement transaction parameters"},
        fee_increase_pct: %{type: :number},
        action: %{type: :string},
        estimated_additional_cost_gwei: %{type: :number}
      }
    }

  require Logger

  @min_bump_pct 10.0

  def handler(input, _ctx) do
    action = Map.get(input, :action)
    original = Map.get(input, :original_tx, %{})
    from = Map.get(input, :from)
    bump_pct = max(Map.get(input, :bump_percentage, 12.5), @min_bump_pct)

    case action do
      "speed_up" -> speed_up(original, from, bump_pct)
      "cancel" -> cancel(original, from, bump_pct)
      "replace" -> replace(original, from, bump_pct, input)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  @doc """
  Creates a speed-up replacement: same tx data with higher gas fees.
  """
  def speed_up(original, from, bump_pct) do
    with {:ok, bumped_fees} <- bump_fees(original, bump_pct) do
      replacement = %{
        nonce: get_field(original, :nonce),
        from: from,
        to: get_field(original, :to),
        value: get_field(original, :value, "0"),
        data: get_field(original, :data, "0x"),
        gas_limit: get_field(original, :gas_limit, 21_000),
        max_fee_per_gas_gwei: bumped_fees.max_fee,
        max_priority_fee_per_gas_gwei: bumped_fees.max_priority_fee,
        type: "0x2"
      }

      additional_cost = calculate_additional_cost(original, bumped_fees)

      {:ok,
       %{
         replacement_tx: replacement,
         fee_increase_pct: Float.round(bump_pct, 1),
         action: "speed_up",
         estimated_additional_cost_gwei: Float.round(additional_cost, 4)
       }}
    end
  end

  @doc """
  Creates a cancellation replacement: zero-value self-transfer with higher gas fees.
  """
  def cancel(original, from, bump_pct) do
    with {:ok, bumped_fees} <- bump_fees(original, bump_pct) do
      replacement = %{
        nonce: get_field(original, :nonce),
        from: from,
        to: from,
        value: "0",
        data: "0x",
        gas_limit: 21_000,
        max_fee_per_gas_gwei: bumped_fees.max_fee,
        max_priority_fee_per_gas_gwei: bumped_fees.max_priority_fee,
        type: "0x2"
      }

      additional_cost = calculate_additional_cost(original, bumped_fees)

      {:ok,
       %{
         replacement_tx: replacement,
         fee_increase_pct: Float.round(bump_pct, 1),
         action: "cancel",
         estimated_additional_cost_gwei: Float.round(additional_cost, 4),
         note: "Sends 0 ETH to self to cancel the pending transaction"
       }}
    end
  end

  @doc """
  Creates a replacement transaction with new data/value and higher gas fees.
  """
  def replace(original, from, bump_pct, input) do
    with {:ok, bumped_fees} <- bump_fees(original, bump_pct) do
      replacement = %{
        nonce: get_field(original, :nonce),
        from: from,
        to: Map.get(input, :new_to, get_field(original, :to)),
        value: Map.get(input, :new_value, get_field(original, :value, "0")),
        data: Map.get(input, :new_data, get_field(original, :data, "0x")),
        gas_limit: get_field(original, :gas_limit, 21_000),
        max_fee_per_gas_gwei: bumped_fees.max_fee,
        max_priority_fee_per_gas_gwei: bumped_fees.max_priority_fee,
        type: "0x2"
      }

      additional_cost = calculate_additional_cost(original, bumped_fees)

      {:ok,
       %{
         replacement_tx: replacement,
         fee_increase_pct: Float.round(bump_pct, 1),
         action: "replace",
         estimated_additional_cost_gwei: Float.round(additional_cost, 4)
       }}
    end
  end

  defp bump_fees(original, bump_pct) do
    original_max = get_field(original, :max_fee_per_gas_gwei)
    original_priority = get_field(original, :max_priority_fee_per_gas_gwei)

    if is_nil(original_max) or is_nil(original_priority) do
      {:error, "Original transaction must include max_fee_per_gas_gwei and max_priority_fee_per_gas_gwei"}
    else
      factor = 1 + bump_pct / 100
      {:ok, %{
        max_fee: original_max * factor,
        max_priority_fee: original_priority * factor
      }}
    end
  end

  defp calculate_additional_cost(original, bumped_fees) do
    gas_limit = get_field(original, :gas_limit, 21_000)
    original_max = get_field(original, :max_fee_per_gas_gwei, 0)
    (bumped_fees.max_fee - original_max) * gas_limit
  end

  defp get_field(map, key, default \\ nil) when is_atom(key) do
    Map.get(map, key) || Map.get(map, to_string(key)) || default
  end
end
