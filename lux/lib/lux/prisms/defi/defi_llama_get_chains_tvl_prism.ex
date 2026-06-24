defmodule Lux.Prisms.DeFi.DefiLlamaGetChainsTvlPrism do
  @moduledoc """
  A prism for retrieving TVL data across all chains from DeFiLlama.

  ## Examples

      iex> Lux.Prisms.DeFi.DefiLlamaGetChainsTvlPrism.handler(%{limit: 10}, %{name: "Agent"})
      {:ok, %{
        chains: [%{name: "Ethereum", tvl: 45_678_901_234.56}, ...]
      }}
  """

  use Lux.Prism,
    name: "DeFiLlama Get Chains TVL",
    description: "Retrieves TVL data for all chains from DeFiLlama",
    input_schema: %{
      type: :object,
      properties: %{
        limit: %{type: :integer, description: "Max number of chains to return", default: 20}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        chains: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string},
              tvl: %{type: :number}
            }
          }
        }
      },
      required: ["chains"]
    }

  require Logger

  @base_url "https://api.llama.fi"

  def handler(params, agent) do
    limit = Map.get(params, :limit, 20)
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} fetching chains TVL (top #{limit})")

    case Req.get("#{@base_url}/v2/chains") do
      {:ok, %{status: 200, body: chains}} when is_list(chains) ->
        sorted = chains
        |> Enum.sort_by(fn c -> -(c["tvl"] || 0) end)
        |> Enum.take(limit)
        |> Enum.map(fn c -> %{name: c["name"], tvl: c["tvl"] || 0} end)

        Logger.info("Fetched TVL for #{length(sorted)} chains")
        {:ok, %{chains: sorted}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body["message"] || "Error"}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
