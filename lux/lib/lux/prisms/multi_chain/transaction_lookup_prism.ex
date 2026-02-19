defmodule Lux.Prisms.MultiChain.TransactionLookupPrism do
  @moduledoc """
  A prism that looks up transaction details across multiple chains.

  Can search for a transaction by hash on a specific chain, or scan multiple
  chains to find a transaction when the origin chain is unknown.

  ## Examples

      # Lookup on a specific chain
      iex> Lux.Prisms.MultiChain.TransactionLookupPrism.run(%{
      ...>   tx_hash: "0xabc...",
      ...>   chain: "ethereum"
      ...> })
      {:ok, %{chain: "ethereum", hash: "0xabc...", ...}}

      # Search across multiple chains
      iex> Lux.Prisms.MultiChain.TransactionLookupPrism.run(%{
      ...>   tx_hash: "0xabc...",
      ...>   chains: ["ethereum", "polygon", "bsc"]
      ...> })
      {:ok, %{found_on: "polygon", transaction: %{...}}}
  """

  use Lux.Prism,
    name: "Transaction Lookup",
    description: "Looks up transaction details across one or more EVM chains",
    input_schema: %{
      type: :object,
      properties: %{
        tx_hash: %{
          type: :string,
          description: "Transaction hash to look up"
        },
        chain: %{
          type: :string,
          description: "Specific chain to search (if known)"
        },
        chains: %{
          type: :array,
          items: %{type: :string},
          description: "List of chains to search (if chain unknown)",
          default: ["ethereum", "polygon", "bsc", "arbitrum", "optimism", "base"]
        }
      },
      required: ["tx_hash"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        found_on: %{type: :string},
        transaction: %{
          type: :object,
          properties: %{
            hash: %{type: :string},
            from: %{type: :string},
            to: %{type: :string},
            value: %{type: :string},
            status: %{type: :string},
            block_number: %{type: :integer}
          }
        }
      }
    }

  alias Lux.MultiChain.Aggregator

  def handler(input, _ctx) do
    tx_hash = get_field(input, :tx_hash)
    chain = get_field(input, :chain)

    if chain do
      lookup_single(tx_hash, String.to_atom(chain))
    else
      chains =
        input
        |> get_field(:chains, ["ethereum", "polygon", "bsc", "arbitrum", "optimism", "base"])
        |> Enum.map(&String.to_atom/1)

      lookup_multi(tx_hash, chains)
    end
  end

  defp lookup_single(tx_hash, chain) do
    case Aggregator.get_transaction(chain, tx_hash) do
      {:ok, tx} ->
        {:ok,
         %{
           found_on: to_string(chain),
           transaction: format_tx(tx)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp lookup_multi(tx_hash, chains) do
    case Aggregator.find_transaction(tx_hash, chains) do
      {:ok, {chain, tx}} ->
        {:ok,
         %{
           found_on: to_string(chain),
           transaction: format_tx(tx)
         }}

      {:error, :not_found} ->
        {:error, "Transaction not found on any of the specified chains"}
    end
  end

  defp format_tx(tx) do
    %{
      hash: tx.hash,
      chain: to_string(tx.chain),
      chain_id: tx.chain_id,
      from: tx.from,
      to: tx.to,
      value: tx.value,
      value_decimal: tx.value_decimal,
      status: to_string(tx.status),
      block_number: tx.block_number,
      gas: tx.gas,
      gas_price: tx.gas_price,
      nonce: tx.nonce
    }
  end

  defp get_field(input, field, default \\ nil) do
    Map.get(input, field) || Map.get(input, to_string(field)) || default
  end
end
