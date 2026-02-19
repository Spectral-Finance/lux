defmodule Lux.Prisms.MultiChain.ChainSummaryPrism do
  @moduledoc """
  A prism that provides a comprehensive summary of multiple chains.

  Fetches latest block numbers, gas prices, and optionally balances across
  multiple chains in parallel.

  ## Examples

      iex> Lux.Prisms.MultiChain.ChainSummaryPrism.run(%{
      ...>   chains: ["ethereum", "polygon", "bsc"]
      ...> })
      {:ok, %{
        summaries: [
          %{chain: "ethereum", latest_block: 18000000, gas_price_gwei: 30.0, ...},
          %{chain: "polygon", latest_block: 50000000, gas_price_gwei: 50.0, ...},
          ...
        ],
        chains_queried: 3
      }}
  """

  use Lux.Prism,
    name: "Multi-Chain Summary",
    description: "Provides a comprehensive status summary across multiple EVM chains",
    input_schema: %{
      type: :object,
      properties: %{
        chains: %{
          type: :array,
          items: %{type: :string},
          description: "List of chain names to summarize",
          default: ["ethereum", "polygon", "bsc"]
        },
        address: %{
          type: :string,
          description: "Optional address to include balance for"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        summaries: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              chain: %{type: :string},
              chain_id: %{type: :integer},
              latest_block: %{type: :integer},
              gas_price_gwei: %{type: :number},
              fast_gas_gwei: %{type: :number}
            }
          }
        },
        chains_queried: %{type: :integer}
      }
    }

  alias Lux.MultiChain.Aggregator

  def handler(input, _ctx) do
    chains =
      input
      |> get_field(:chains, ["ethereum", "polygon", "bsc"])
      |> Enum.map(fn
        c when is_atom(c) -> c
        c when is_binary(c) -> String.to_atom(c)
      end)

    address = get_field(input, :address)
    opts = if address, do: [address: address], else: []

    case Aggregator.chain_summary(chains, opts) do
      {:ok, summaries} ->
        formatted =
          Enum.map(summaries, fn s ->
            base = %{
              chain: to_string(s.chain),
              chain_id: s.chain_id,
              latest_block: s.latest_block,
              gas_price_gwei: s.gas_price_gwei,
              fast_gas_gwei: s.fast_gas_gwei,
              timestamp: DateTime.to_iso8601(s.timestamp)
            }

            if Map.has_key?(s, :balance) do
              Map.put(base, :balance, s.balance)
            else
              base
            end
          end)

        {:ok, %{summaries: formatted, chains_queried: length(chains)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_field(input, field, default \\ nil) do
    Map.get(input, field) || Map.get(input, to_string(field)) || default
  end
end
