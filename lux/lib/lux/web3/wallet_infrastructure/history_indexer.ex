defmodule Lux.Web3.WalletInfrastructure.HistoryIndexer do
  @moduledoc """
  Indexes and queries confirmed transaction history, execution receipts,
  and calculates historical gas expenditure across chains.
  """

  @type history_entry :: %{
          tx_hash: String.t(),
          from: String.t(),
          to: String.t(),
          chain_id: non_neg_integer(),
          block_number: non_neg_integer(),
          gas_used: non_neg_integer(),
          effective_gas_price: non_neg_integer(),
          status: :success | :reverted,
          timestamp: String.t()
        }

  @doc """
  Appends an execution receipt to the history log.
  """
  @spec record_receipt(list(history_entry()), history_entry()) :: list(history_entry())
  def record_receipt(history, entry) when is_list(history) and is_map(entry) do
    [entry | history]
  end

  @doc """
  Queries transaction history for a given address and optional chain ID.
  """
  @spec query_history(list(history_entry()), String.t(), keyword()) :: list(history_entry())
  def query_history(history, address, opts \\ []) when is_list(history) do
    target_addr = String.downcase(address)
    target_chain = Keyword.get(opts, :chain_id)

    history
    |> Enum.filter(fn entry ->
      matches_addr =
        String.downcase(entry.from) == target_addr or String.downcase(entry.to) == target_addr

      matches_chain =
        if target_chain, do: entry.chain_id == target_chain, else: true

      matches_addr and matches_chain
    end)
  end

  @doc """
  Calculates total gas expenditure across all indexed transactions for an address.
  """
  @spec calculate_total_gas_spent(list(history_entry()), String.t()) :: float()
  def calculate_total_gas_spent(history, address) do
    target_addr = String.downcase(address)

    history
    |> Enum.filter(&(String.downcase(&1.from) == target_addr))
    |> Enum.reduce(0.0, fn entry, acc ->
      gas_wei = entry.gas_used * entry.effective_gas_price
      acc + (gas_wei / 1_000_000_000_000_000_000.0)
    end)
    |> Float.round(6)
  end
end
