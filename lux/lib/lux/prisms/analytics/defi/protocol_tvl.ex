defmodule Lux.Prisms.Analytics.Defi.ProtocolTvlPrism do
  @moduledoc """
  Normalizes and structures DeFi protocol TVL metrics from DeFiLlama.
  """

  use Lux.Prism,
    name: "DeFi Protocol TVL",
    description: "Parses total value locked, 24h TVL change, and multi-chain TVL distribution",
    input_schema: %{
      type: :object,
      properties: %{
        protocol_data: %{type: :object, description: "Raw protocol TVL JSON from DeFiLlama"}
      },
      required: ["protocol_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        name: %{type: :string},
        symbol: %{type: :string},
        category: %{type: :string},
        total_tvl_usd: %{type: :number},
        change_1d_pct: %{type: :number},
        chain_tvls: %{type: :object}
      },
      required: ["name", "total_tvl_usd", "change_1d_pct"]
    }

  alias Lux.Analytics.Defi.DefiLlama

  def handler(input, _ctx) do
    data = Map.get(input, :protocol_data) || Map.get(input, "protocol_data", %{})
    parsed = DefiLlama.parse_protocol_tvl(data)
    {:ok, parsed}
  end
end
