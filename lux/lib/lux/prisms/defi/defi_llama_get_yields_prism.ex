defmodule Lux.Prisms.DeFi.DefiLlamaGetYieldsPrism do
  @moduledoc """
  A prism for retrieving yield farming data from DeFiLlama Yields API.

  ## Examples

      iex> Lux.Prisms.DeFi.DefiLlamaGetYieldsPrism.handler(%{
      ...>   min_apy: 10.0,
      ...>   min_tvl: 1_000_000,
      ...>   limit: 10
      ...> }, %{name: "Agent"})
      {:ok, %{
        pools: [%{
          pool: "USDC-USDT Curve",
          chain: "Ethereum",
          project: "curve",
          apy: 12.34,
          tvl_usd: 45_678_901.0
        }]
      }}
  """

  use Lux.Prism,
    name: "DeFiLlama Get Yields",
    description: "Retrieves yield farming pool data from DeFiLlama, with optional filtering",
    input_schema: %{
      type: :object,
      properties: %{
        min_apy: %{type: :number, description: "Minimum APY filter (%)"},
        max_apy: %{type: :number, description: "Maximum APY filter (%)"},
        min_tvl: %{type: :number, description: "Minimum TVL in USD"},
        chain: %{type: :string, description: "Filter by blockchain"},
        project: %{type: :string, description: "Filter by project name"},
        limit: %{type: :integer, description: "Max results to return", default: 20}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        pools: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              pool: %{type: :string},
              chain: %{type: :string},
              project: %{type: :string},
              apy: %{type: :number},
              tvl_usd: %{type: :number}
            }
          }
        }
      },
      required: ["pools"]
    }

  require Logger

  @base_url "https://yields.llama.fi"

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} fetching DeFi yields")

    case Req.get("#{@base_url}/pools") do
      {:ok, %{status: 200, body: %{"data" => pools}}} ->
        filtered = pools
        |> filter_pools(params)
        |> Enum.take(Map.get(params, :limit, 20))
        |> Enum.map(fn p ->
          %{
            pool: p["pool"],
            chain: p["chain"],
            project: p["project"],
            apy: p["apy"],
            tvl_usd: p["tvlUsd"]
          }
        end)

        Logger.info("Found #{length(filtered)} yield pools matching criteria")
        {:ok, %{pools: filtered}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body["message"] || "Error fetching yields"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp filter_pools(pools, params) do
    pools
    |> filter_by(:apy, Map.get(params, :min_apy), :gte)
    |> filter_by(:apy, Map.get(params, :max_apy), :lte)
    |> filter_by(:tvlUsd, Map.get(params, :min_tvl), :gte)
    |> filter_by_string(:chain, Map.get(params, :chain))
    |> filter_by_string(:project, Map.get(params, :project))
    |> Enum.sort_by(fn p -> -(p["apy"] || 0) end)
  end

  defp filter_by(pools, _key, nil, _), do: pools
  defp filter_by(pools, key, val, :gte), do: Enum.filter(pools, fn p -> (p[to_string(key)] || 0) >= val end)
  defp filter_by(pools, key, val, :lte), do: Enum.filter(pools, fn p -> (p[to_string(key)] || 0) <= val end)

  defp filter_by_string(pools, _key, nil), do: pools
  defp filter_by_string(pools, key, val) do
    Enum.filter(pools, fn p ->
      String.downcase(p[to_string(key)] || "") == String.downcase(val)
    end)
  end
end
