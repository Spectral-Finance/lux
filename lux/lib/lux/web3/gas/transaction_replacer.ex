defmodule Lux.Web3.Gas.TransactionReplacer do
  @moduledoc """
  Transaction replacement (speed up / cancel) via EIP-1559.
  """

  alias Lux.Web3.Gas.Types

  @doc """
  Creates a speed-up replacement transaction.
  """
  @spec speed_up(map(), %{max_fee_per_gas: integer(), max_priority_fee_per_gas: integer()}) ::
          {:ok, Types.Replacement.t()} | {:error, String.t()}
  def speed_up(original_tx, new_fees) do
    original_fee = Map.get(original_tx, :max_fee_per_gas, 0)
    required_min = floor(original_fee * 1.1)
    new_fee = Map.get(new_fees, :max_fee_per_gas, 0)

    if new_fee < required_min do
      {:error,
       "Speed-up fee #{new_fee} must be at least 10% higher than original #{original_fee} (minimum: #{required_min})"}
    else
      replacement = %Types.Replacement{
        original_tx_hash: Map.get(original_tx, :hash, ""),
        replacement_type: :speed_up,
        new_nonce: Map.get(original_tx, :nonce, 0),
        new_max_fee_per_gas: new_fee,
        new_max_priority_fee_per_gas: Map.get(new_fees, :max_priority_fee_per_gas, 0),
        created_at: DateTime.utc_now()
      }

      {:ok, replacement}
    end
  end

  @doc """
  Creates a cancel replacement transaction.
  """
  @spec cancel(String.t(), integer(), integer(), integer()) ::
          {:ok, Types.Replacement.t()} | {:error, String.t()}
  def cancel(original_tx_hash, nonce, max_fee_per_gas, max_priority_fee_per_gas) do
    if max_fee_per_gas <= 0 do
      {:error, "max_fee_per_gas must be positive"}
    else
      replacement = %Types.Replacement{
        original_tx_hash: original_tx_hash,
        replacement_type: :cancel,
        new_nonce: nonce,
        new_max_fee_per_gas: max_fee_per_gas,
        new_max_priority_fee_per_gas: max_priority_fee_per_gas,
        created_at: DateTime.utc_now()
      }

      {:ok, replacement}
    end
  end

  @doc """
  Validates that a replacement fee satisfies EIP-1559 mempool rules.
  """
  @spec validate_replacement(map(), map()) :: :ok | {:error, String.t()}
  def validate_replacement(original, replacement) do
    orig_fee = Map.get(original, :max_fee_per_gas, 0)
    repl_fee = Map.get(replacement, :max_fee_per_gas, 0)
    min_fee = floor(orig_fee * 1.1)

    cond do
      repl_fee < min_fee ->
        {:error, "Replacement fee #{repl_fee} below minimum #{min_fee} (110% of #{orig_fee})"}

      Map.get(replacement, :max_priority_fee_per_gas, 0) <
        Map.get(original, :max_priority_fee_per_gas, 0) ->
        {:error, "Priority fee must be >= original priority fee"}

      true ->
        :ok
    end
  end
end
