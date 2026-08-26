defmodule LuxApp.TxManager.Batcher do
  @moduledoc """
  Transaction batching implementation to save base gas costs.
  """

  alias LuxApp.TxManager.ABIEncoder

  @doc """
  Groups multiple transaction payloads into a single multicall structure using ABI encoding.
  Saves 21,000 gas per additional transaction batched.
  """
  def create_multicall(transactions) when is_list(transactions) do
    if length(transactions) == 0 do
      {:error, :empty_batch}
    else
      encoded_data = ABIEncoder.encode_multicall(transactions)
      %{
        to: "0xcA11bde05977b3631167028862bE2a173976CA11", # Multicall3 address
        data: encoded_data,
        value: 0,
        estimated_gas_saved: (length(transactions) - 1) * 21_000
      }
    end
  end
end
