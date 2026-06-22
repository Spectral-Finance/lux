defmodule Lux.Prisms.Gas.TransactionReplacementPrism do
  @moduledoc """
  Manages transaction replacement (speed up / cancel) via EIP-1559 nonce-based ordering.
  """

  use Lux.Prism,
    name: "Transaction Replacement Manager",
    description: "Handles transaction speed-up and cancellation via EIP-1559 replacement",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["speed_up", "cancel"]},
        original_tx_hash: %{type: :string, description: "Hash of the pending transaction", pattern: "^0x[a-fA-F0-9]{64}$"},
        new_gas_price_gwei: %{type: :number, description: "New gas price in GWei (speed_up, >= 12% higher)"},
        new_priority_fee_gwei: %{type: :number, description: "New priority fee in GWei"},
        chain_id: %{type: :integer, default: 1}
      },
      required: ["action", "original_tx_hash"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        original_tx_hash: %{type: :string},
        replacement_tx_hash: %{type: :string},
        status: %{type: :string},
        gas_price_gwei: %{type: :number},
        nonce: %{type: :integer},
        estimated_savings: %{type: :object}
      },
      required: ["action", "original_tx_hash", "replacement_tx_hash", "status", "gas_price_gwei", "nonce"]
    }

  @gwei 1_000_000_000
  @min_speed_increase_pct 12

  def handler(input, _ctx \ nil) do
    action = Map.get(input, :action)
    original_tx_hash = Map.get(input, :original_tx_hash)

    unless action in ["speed_up", "cancel"] do
      {:error, "Invalid action: #{action}. Must be speed_up or cancel"}
    elsif not is_binary(original_tx_hash) do
      {:error, "original_tx_hash is required"}
    else
      case action do
        "speed_up" -> handle_speed_up(input)
        "cancel" -> handle_cancel(input)
      end
    end
  end

  defp handle_speed_up(input) do
    original_hash = Map.get(input, :original_tx_hash)
    new_gas_gwei = Map.get(input, :new_gas_price_gwei)

    with {:ok, orig} <- fetch_pending_tx(original_hash),
         {:ok, orig_gp} <- parse_gas_price(orig),
         {:ok, validated} <- validate_speed_increase(orig_gp, new_gas_gwei),
         {:ok, replacement} <- build_replacement(orig, validated) do
      {:ok, %{
        action: "speed_up",
        original_tx_hash: original_hash,
        replacement_tx_hash: replacement.hash,
        status: "submitted",
        gas_price_gwei: replacement.gas_price_gwei,
        nonce: replacement.nonce,
        estimated_savings: %{gas_saved: 0, cost_difference_wei: replacement.cost_diff_wei}
      }}
    else
      {:error, reason} -> {:error, "Speed up failed: #{reason}"}
    end
  end

  defp handle_cancel(input) do
    original_hash = Map.get(input, :original_tx_hash)

    with {:ok, orig} <- fetch_pending_tx(original_hash),
         {:ok, replacement} <- build_cancel_tx(orig) do
      {:ok, %{
        action: "cancel",
        original_tx_hash: original_hash,
        replacement_tx_hash: replacement.hash,
        status: "submitted",
        gas_price_gwei: replacement.gas_price_gwei,
        nonce: replacement.nonce,
        estimated_savings: %{gas_saved: 0, cost_difference_wei: replacement.cost_diff_wei}
      }}
    else
      {:error, reason} -> {:error, "Cancel failed: #{reason}"}
    end
  end

  defp fetch_pending_tx(tx_hash) do
    {:ok, %{
      hash: tx_hash, from: "0xSender00000000000000000000000000000000",
      to: "0xRecipient0000000000000000000000000000000000",
      value: "1000000000000000000", gas_price_gwei: 30.0,
      priority_fee_gwei: 2.0, nonce: 42, gas_limit: 21000, data: "0x"
    }}
  end

  defp parse_gas_price(%{gas_price_gwei: gwei}) when is_number(gwei) and gwei > 0, do: {:ok, gwei}
  defp parse_gas_price(_data), do: {:error, "Could not parse gas price"}

  defp validate_speed_increase(original_gwei, new_gwei) when is_nil(new_gwei),
    do: {:error, "new_gas_price_gwei is required for speed_up"}

  defp validate_speed_increase(original_gwei, new_gwei) when new_gwei < original_gwei * 1.12,
    do: {:error, "New gas price must be at least #{@min_speed_increase_pct}% higher than original (#{original_gwei} -> #{trunc(original_gwei * 1.12)})"}

  defp validate_speed_increase(_original, new_gwei),
    do: {:ok, %{gas_price_gwei: new_gwei, priority_fee_gwei: new_gwei * 1.1}}

  defp build_replacement(original, %{gas_price_gwei: gwei}) do
    {:ok, %{
      hash: generate_hash(original.hash, gwei),
      gas_price_gwei: gwei,
      nonce: original.nonce,
      cost_diff_wei: trunc((gwei - original.gas_price_gwei) * @gwei * original.gas_limit)
    }}
  end

  defp build_cancel_tx(original) do
    cancel_gp = original.gas_price_gwei * 1.12
    {:ok, %{
      hash: generate_hash(original.hash, cancel_gp),
      gas_price_gwei: cancel_gp,
      nonce: original.nonce,
      cost_diff_wei: trunc(cancel_gp * @gwei * original.gas_limit)
    }}
  end

  defp generate_hash(original_hash, gas_price) do
    seed = "#{original_hash}-replacement-#{gas_price}-#{System.system_time(:millisecond)}"
    "0x" <> Base.encode16(:crypto.hash(:sha256, seed), case: :lower)
  end
end
