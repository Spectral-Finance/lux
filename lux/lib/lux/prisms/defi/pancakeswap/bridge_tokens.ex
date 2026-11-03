defmodule Lux.Prisms.Defi.PancakeSwap.BridgeTokensPrism do
  @moduledoc """
  Quotes and plans cross-chain asset bridging across PancakeSwap multi-chain deployments.
  """

  use Lux.Prism,
    name: "Bridge PancakeSwap Tokens",
    description: "Generates cross-chain transfer plan for CAKE and tokens across supported chains",
    input_schema: %{
      type: :object,
      properties: %{
        from_chain: %{type: :integer, description: "Source chain ID (e.g. 56 for BSC)"},
        to_chain: %{type: :integer, description: "Destination chain ID (e.g. 42161 for Arbitrum)"},
        token: %{type: :string, description: "Token symbol (CAKE, USDT, etc.)"},
        amount: %{type: :number, description: "Amount of tokens to bridge"},
        recipient: %{type: :string, description: "Destination recipient wallet address"},
        token_price_usd: %{type: :number, default: 1.0}
      },
      required: ["from_chain", "to_chain", "token", "amount", "recipient"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        from_chain: %{type: :integer},
        to_chain: %{type: :integer},
        token: %{type: :string},
        amount: %{type: :number},
        net_received: %{type: :number},
        total_fee_usd: %{type: :number},
        estimated_minutes: %{type: :integer},
        recipient: %{type: :string},
        status: %{type: :string},
        bridge_id: %{type: :string}
      },
      required: ["from_chain", "to_chain", "token", "amount", "net_received", "status", "bridge_id"]
    }

  alias Lux.Defi.PancakeSwap.CrossChainRouter

  def handler(input, _ctx) do
    from_chain = Map.get(input, :from_chain) || Map.get(input, "from_chain", 56)
    to_chain = Map.get(input, :to_chain) || Map.get(input, "to_chain", 42161)
    token = Map.get(input, :token) || Map.get(input, "token", "CAKE")
    amount = (Map.get(input, :amount) || Map.get(input, "amount", 10.0)) * 1.0
    recipient = Map.get(input, :recipient) || Map.get(input, "recipient", "0x0000000000000000000000000000000000000000")
    token_px = (Map.get(input, :token_price_usd) || Map.get(input, "token_price_usd", 2.50)) * 1.0

    CrossChainRouter.plan_bridge(from_chain, to_chain, token, amount, recipient, token_px)
  end
end
