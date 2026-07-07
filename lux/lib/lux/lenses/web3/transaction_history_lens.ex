defmodule Lux.Lenses.Web3.TransactionHistoryLens do
  @moduledoc """
  A Lux Lens for querying transaction history of managed wallets.
  Returns recorded transactions from the TransactionHistory tracker.
  """

  use Lux.Lens,
    name: "Web3 Transaction History",
    description: "Queries transaction history for a managed wallet address",
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "The wallet address to query transaction history for"
        },
        chain_id: %{
          type: :integer,
          description: "Optional chain ID filter"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of transactions to return (default: 50)"
        }
      },
      required: ["address"]
    }

  @impl true
  def focus(%{address: address} = params, _opts) do
    limit = Map.get(params, :limit, 50)
    chain_id = Map.get(params, :chain_id)

    opts = [limit: limit]
    opts = if chain_id, do: Keyword.put(opts, :chain_id, chain_id), else: opts

    transactions = Lux.Web3.TransactionHistory.list_for_address(address, opts)
    total_count = Lux.Web3.TransactionHistory.count_for_address(address)

    formatted =
      Enum.map(transactions, fn tx ->
        %{
          tx_hash: tx.tx_hash,
          from: tx.from,
          to: tx.to,
          value_wei: tx.value,
          chain_id: tx.chain_id,
          status: Atom.to_string(tx.status),
          block_number: tx.block_number,
          gas_used: tx.gas_used,
          nonce: tx.nonce,
          submitted_at: DateTime.to_iso8601(tx.submitted_at),
          confirmed_at: if(tx.confirmed_at, do: DateTime.to_iso8601(tx.confirmed_at))
        }
      end)

    {:ok, %{
      address: address,
      total_transactions: total_count,
      transactions: formatted,
      showing: length(formatted)
    }}
  end
end
