defmodule Lux.Prisms.Web3.TransactionManagerPrism do
  @moduledoc """
  Gas quotes and transaction preflight for Lux agents.

  Pass RPC options in the context, e.g.
  `run(%{action: "quote"}, rpc_url: "http://localhost:8545")`.
  Transactions and batch calls use JSON-RPC string keys. This prism prepares
  plans; signing and submission remain explicit application decisions.
  """

  use Lux.Prism,
    name: "Transaction Manager",
    description: "Predicts gas fees, simulates transactions and plans economical batches",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["quote", "prepare", "batch"]},
        transaction: %{type: :object},
        calls: %{type: :array, items: %{type: :object}},
        from: %{type: :string},
        contract: %{type: :string}
      },
      required: ["action"]
    },
    output_schema: %{type: :object}

  alias Lux.Web3.TransactionManager

  @impl true
  def handler(%{action: "quote"}, opts) when is_list(opts), do: TransactionManager.quote(opts)

  def handler(%{action: "prepare", transaction: tx}, opts) when is_list(opts),
    do: TransactionManager.prepare(tx, opts)

  def handler(%{action: "batch", calls: calls, from: from, contract: contract}, opts)
      when is_list(opts),
      do: TransactionManager.plan_batch(calls, from, contract, opts)

  def handler(_, _), do: {:error, :invalid_transaction_manager_input_or_context}
end
