defmodule Lux.Prisms.MultiChain.CrossChainBalancePrism do
  @moduledoc """
  A prism that aggregates native token balances across multiple EVM chains.

  Queries balances in parallel and returns a unified view of an address's
  holdings across all specified chains.

  ## Examples

      iex> Lux.Prisms.MultiChain.CrossChainBalancePrism.run(%{
      ...>   address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
      ...>   chains: ["ethereum", "polygon", "bsc"]
      ...> })
      {:ok, %{
        address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        balances: [
          %{chain: "ethereum", balance: 1.5, symbol: "ETH"},
          %{chain: "polygon", balance: 100.0, symbol: "MATIC"},
          %{chain: "bsc", balance: 0.5, symbol: "BNB"}
        ],
        total_chains_queried: 3,
        successful_chains: 3
      }}
  """

  use Lux.Prism,
    name: "Cross-Chain Balance Aggregator",
    description: "Aggregates native token balances across multiple EVM chains",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum-compatible address to check"
        },
        chains: %{
          type: :array,
          items: %{type: :string},
          description:
            "List of chain names to query (ethereum, polygon, bsc, arbitrum, optimism, base, avalanche)",
          default: ["ethereum", "polygon", "bsc"]
        }
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        address: %{type: :string},
        balances: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              chain: %{type: :string},
              balance: %{type: :number},
              symbol: %{type: :string},
              chain_id: %{type: :integer}
            }
          }
        },
        total_chains_queried: %{type: :integer},
        successful_chains: %{type: :integer}
      }
    }

  alias Lux.MultiChain.Aggregator

  def handler(%{address: address} = input, _ctx) do
    chains =
      input
      |> Map.get(:chains, ["ethereum", "polygon", "bsc"])
      |> Enum.map(&String.to_atom/1)

    case Aggregator.get_balances(address, chains) do
      {:ok, balances} ->
        formatted =
          Enum.map(balances, fn bal ->
            %{
              chain: to_string(bal.chain),
              balance: bal.balance_formatted,
              symbol: bal.token_symbol,
              chain_id: bal.chain_id
            }
          end)

        {:ok,
         %{
           address: address,
           balances: formatted,
           total_chains_queried: length(chains),
           successful_chains: length(formatted)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(%{"address" => _} = input, ctx) do
    input
    |> atomize_keys()
    |> handler(ctx)
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end
