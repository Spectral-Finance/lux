defmodule Lux.Prisms.DeFi.DefiLlamaGetProtocolTvlPrism do
  @moduledoc """
  A prism for retrieving TVL (Total Value Locked) data from DeFiLlama.

  Uses the DeFiLlama public API (no authentication required).

  ## Examples

      iex> Lux.Prisms.DeFi.DefiLlamaGetProtocolTvlPrism.handler(%{protocol: "uniswap"}, %{name: "Agent"})
      {:ok, %{
        name: "Uniswap",
        tvl: 5_432_198_765.23,
        chain_tvls: %{"Ethereum" => 4_123_456_789.0, "Arbitrum" => 987_654_321.0},
        category: "Dexes",
        change_1d: 2.34,
        change_7d: -5.67
      }}
  """

  use Lux.Prism,
    name: "DeFiLlama Get Protocol TVL",
    description: "Retrieves TVL and protocol metrics from DeFiLlama",
    input_schema: %{
      type: :object,
      properties: %{
        protocol: %{
          type: :string,
          description: "Protocol slug (e.g., 'uniswap', 'aave', 'curve')"
        }
      },
      required: ["protocol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        name: %{type: :string, description: "Protocol name"},
        tvl: %{type: :number, description: "Current TVL in USD"},
        chain_tvls: %{type: :object, description: "TVL breakdown by chain"},
        category: %{type: :string, description: "Protocol category"},
        change_1d: %{type: :number, description: "1-day TVL change %"},
        change_7d: %{type: :number, description: "7-day TVL change %"}
      },
      required: ["name", "tvl"]
    }

  require Logger

  @base_url "https://api.llama.fi"

  def handler(%{protocol: protocol}, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} fetching TVL for protocol: #{protocol}")

    url = "#{@base_url}/protocol/#{URI.encode(protocol)}"

    case Req.get(url) do
      {:ok, %{status: 200, body: data}} ->
        result = %{
          name: data["name"],
          tvl: data["currentChainTvls"] |> Enum.reduce(0.0, fn {_, v}, acc -> acc + v end),
          chain_tvls: data["currentChainTvls"] || %{},
          category: data["category"],
          change_1d: data["change_1d"],
          change_7d: data["change_7d"]
        }
        Logger.info("TVL data fetched for #{protocol}: $#{result.tvl}")
        {:ok, result}

      {:ok, %{status: status, body: body}} ->
        msg = body["message"] || "Protocol not found"
        Logger.error("DeFiLlama TVL error for #{protocol}: #{status} - #{msg}")
        {:error, {status, msg}}

      {:error, reason} ->
        Logger.error("DeFiLlama TVL request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
