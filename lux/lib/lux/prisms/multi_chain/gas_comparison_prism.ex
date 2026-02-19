defmodule Lux.Prisms.MultiChain.GasComparisonPrism do
  @moduledoc """
  A prism that compares gas prices across multiple EVM chains.

  Fetches current gas prices from all specified chains and returns them
  sorted by cost, making it easy to identify the cheapest chain for
  transactions.

  ## Examples

      iex> Lux.Prisms.MultiChain.GasComparisonPrism.run(%{
      ...>   chains: ["ethereum", "polygon", "bsc", "arbitrum"]
      ...> })
      {:ok, %{
        gas_prices: [
          %{chain: "polygon", standard_gwei: 30.0, fast_gwei: 40.0},
          %{chain: "bsc", standard_gwei: 3.0, fast_gwei: 5.0},
          ...
        ],
        cheapest_chain: "polygon",
        most_expensive_chain: "ethereum"
      }}
  """

  use Lux.Prism,
    name: "Gas Price Comparison",
    description: "Compares gas prices across multiple EVM chains",
    input_schema: %{
      type: :object,
      properties: %{
        chains: %{
          type: :array,
          items: %{type: :string},
          description: "List of chain names to compare gas prices",
          default: ["ethereum", "polygon", "bsc", "arbitrum", "optimism", "base"]
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        gas_prices: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              chain: %{type: :string},
              safe_gwei: %{type: :number},
              standard_gwei: %{type: :number},
              fast_gwei: %{type: :number}
            }
          }
        },
        cheapest_chain: %{type: :string},
        most_expensive_chain: %{type: :string}
      }
    }

  alias Lux.MultiChain.Aggregator

  def handler(input, _ctx) do
    chains =
      input
      |> get_field(:chains, ["ethereum", "polygon", "bsc", "arbitrum", "optimism", "base"])
      |> Enum.map(fn
        c when is_atom(c) -> c
        c when is_binary(c) -> String.to_atom(c)
      end)

    case Aggregator.get_gas_prices(chains) do
      {:ok, prices} ->
        formatted =
          prices
          |> Enum.map(fn p ->
            %{
              chain: to_string(p.chain),
              chain_id: p.chain_id,
              safe_gwei: p.safe_gas_price,
              standard_gwei: p.propose_gas_price,
              fast_gwei: p.fast_gas_price,
              base_fee_gwei: p.base_fee
            }
          end)
          |> Enum.sort_by(& &1.standard_gwei)

        cheapest = List.first(formatted)
        most_expensive = List.last(formatted)

        {:ok,
         %{
           gas_prices: formatted,
           cheapest_chain: cheapest && cheapest.chain,
           most_expensive_chain: most_expensive && most_expensive.chain
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_field(input, field, default \\ nil) do
    Map.get(input, field) || Map.get(input, to_string(field)) || default
  end
end
