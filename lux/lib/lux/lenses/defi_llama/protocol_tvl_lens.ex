defmodule Lux.Lenses.DeFiLlama.ProtocolTVL do
  @moduledoc """
  Lens for fetching TVL data for a specific DeFi protocol.

  ## Examples

  ```elixir
  # Get TVL data for Uniswap
  Lux.Lenses.DeFiLlama.ProtocolTVL.focus(%{protocol: "uniswap"})

  # Get TVL data for Aave
  Lux.Lenses.DeFiLlama.ProtocolTVL.focus(%{protocol: "aave"})
  ```
  """

  use Lux.Lens,
    name: "DeFiLlama.ProtocolTVL",
    description: "Fetches TVL data, chain breakdown, and metadata for a specific DeFi protocol",
    url: "https://api.llama.fi/protocol/:protocol",
    method: :get,
    headers: [{"accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        protocol: %{
          type: :string,
          description: "Protocol slug (e.g., 'uniswap', 'aave', 'lido')"
        }
      },
      required: ["protocol"]
    }

  def before_focus(params) do
    protocol = Map.get(params, :protocol, "")
    %{params | protocol: URI.encode(protocol)}
  end

  def after_focus(body) when is_map(body) do
    {:ok, %{
      name: body["name"] || Map.get(body, "protocolId", ""),
      address: body["address"],
      symbol: body["symbol"],
      chains: body["chainTvls"] || Map.get(body, "chains", []),
      tvl: body["tvl"] || [],
      currentChainBreakdown: body["currentChainBreakdown"] || Map.get(body, "currentChain", []),
      misBehaviors: body["misBehaviors"] || [],
      github: body["github"] || [],
      audits: body["audits"],
      audit_notes: body["audit_notes"],
      oracles: body["oracles"],
      deployed: body["deployed"] || [],
      timestamp: DateTime.utc_now()
    }}
  end

  def after_focus(body) do
    {:ok, %{raw: body, timestamp: DateTime.utc_now()}}
  end
end
