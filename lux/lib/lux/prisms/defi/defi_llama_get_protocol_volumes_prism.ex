defmodule Lux.Prisms.DeFi.DefiLlamaGetProtocolVolumesPrism do
  @moduledoc """
  A prism for retrieving trading volume data from DeFiLlama.

  ## Examples

      iex> Lux.Prisms.DeFi.DefiLlamaGetProtocolVolumesPrism.handler(%{protocol: "uniswap"}, %{name: "Agent"})
      {:ok, %{
        protocol: "uniswap",
        total_volume_24h: 1_234_567_890.0,
        total_volume_7d: 8_765_432_100.0,
        change_1d: 5.67,
        chains: ["Ethereum", "Arbitrum", "Polygon"]
      }}
  """

  use Lux.Prism,
    name: "DeFiLlama Get Protocol Volumes",
    description: "Retrieves trading volume data for a DeFi protocol from DeFiLlama",
    input_schema: %{
      type: :object,
      properties: %{
        protocol: %{type: :string, description: "Protocol slug (e.g., 'uniswap', 'curve')"}
      },
      required: ["protocol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        protocol: %{type: :string},
        total_volume_24h: %{type: :number},
        total_volume_7d: %{type: :number},
        change_1d: %{type: :number},
        chains: %{type: :array, items: %{type: :string}}
      },
      required: ["protocol", "total_volume_24h"]
    }

  require Logger

  @base_url "https://api.llama.fi"

  def handler(%{protocol: protocol}, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} fetching volumes for #{protocol}")

    case Req.get("#{@base_url}/summary/dexs/#{URI.encode(protocol)}") do
      {:ok, %{status: 200, body: data}} ->
        result = %{
          protocol: protocol,
          total_volume_24h: data["total24h"] || 0,
          total_volume_7d: data["total7d"] || 0,
          change_1d: data["change_1d"],
          chains: Map.keys(data["chainBreakdown"] || %{})
        }
        Logger.info("Volume data fetched for #{protocol}: $#{result.total_volume_24h} 24h")
        {:ok, result}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body["message"] || "Error"}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
