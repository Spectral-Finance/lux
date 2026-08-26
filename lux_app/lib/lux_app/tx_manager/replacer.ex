defmodule LuxApp.TxManager.Replacer do
  @moduledoc """
  Transaction replacement mechanism (Speed up / Cancel) using Replace-by-Fee (RBF).
  EVM nodes require at least a 10% bump in both maxFeePerGas and maxPriorityFeePerGas.
  Bounded retry limit prevents infinite recursion.
  """

  alias LuxApp.TxManager.TxEncoder

  @rpc_adapter Application.compile_env(:lux_app, :rpc_adapter, LuxApp.TxManager.RealRPC)
  @max_retries 3

  @doc """
  Speeds up a transaction by bumping fees by 10% and resubmitting (up to max_retries).
  """
  def speed_up(tx, retry_count \\ 0) do
    if retry_count >= @max_retries do
      {:error, :max_replacement_retries_exceeded}
    else
      new_tx = %{
        tx |
        max_fee_per_gas: bump_10_percent(tx.max_fee_per_gas),
        max_priority_fee_per_gas: bump_10_percent(tx.max_priority_fee_per_gas)
      }
      
      signed_raw_tx = TxEncoder.encode_and_sign(new_tx)
      final_tx = Map.put(new_tx, :raw_tx, signed_raw_tx)

      send_replacement(final_tx, retry_count)
    end
  end

  @doc """
  Cancels a transaction by sending an empty payload to self with bumped fees.
  """
  def cancel(tx, retry_count \\ 0) do
    if retry_count >= @max_retries do
      {:error, :max_replacement_retries_exceeded}
    else
      new_tx = %{
        to: tx.from,
        from: tx.from,
        value: 0,
        data: "0x",
        nonce: tx.nonce,
        max_fee_per_gas: bump_10_percent(tx.max_fee_per_gas),
        max_priority_fee_per_gas: bump_10_percent(tx.max_priority_fee_per_gas)
      }
      
      signed_raw_tx = TxEncoder.encode_and_sign(new_tx)
      final_tx = Map.put(new_tx, :raw_tx, signed_raw_tx)

      send_replacement(final_tx, retry_count)
    end
  end

  defp send_replacement(final_tx, retry_count) do
    case @rpc_adapter.send_transaction(final_tx) do
      {:ok, hash} ->
        {:ok, hash, final_tx}

      {:error, :replacement_underpriced} ->
        # Bump again automatically up to max_retries
        speed_up(final_tx, retry_count + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp bump_10_percent(fee) when is_integer(fee) do
    div(fee * 110, 100)
  end

  defp bump_10_percent(fee) do
    trunc(fee * 1.10)
  end
end
