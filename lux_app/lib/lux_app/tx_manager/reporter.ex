defmodule LuxApp.TxManager.Reporter do
  @moduledoc """
  Calculates and reports gas savings from transaction batching.
  """

  @doc """
  Calculates gas savings metrics comparing original individual transactions against batched transaction.
  """
  def calculate_savings(original_txs, _batched_tx) when is_list(original_txs) do
    count = length(original_txs)

    if count == 0 do
      %{
        original_gas_cost: 0,
        batched_gas_cost: 0,
        gas_saved: 0,
        saved_percentage: 0.0
      }
    else
      original_gas = count * 21_000
      batched_gas = 21_000
      gas_saved = max(0, original_gas - batched_gas)
      saved_percentage = Float.round((gas_saved / original_gas) * 100, 2)

      %{
        original_gas_cost: original_gas,
        batched_gas_cost: batched_gas,
        gas_saved: gas_saved,
        saved_percentage: saved_percentage
      }
    end
  end
end
