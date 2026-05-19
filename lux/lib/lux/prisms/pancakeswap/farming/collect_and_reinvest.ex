defmodule Lux.Prisms.PancakeSwap.Farming.CollectAndReinvest do
  @moduledoc """
  A prism for collecting rewards and reinvesting them into a position.
  This is a simplified version of auto-compounding.
  """

  use Lux.Prism,
    name: "PancakeSwap Collect and Reinvest",
    description: "Harvests rewards and adds them back to the liquidity position",
    input_schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string, enum: ["bsc", "ethereum"], default: "bsc"},
        token_id: %{type: :integer, description: "The ID of the position NFT"},
        reinvest_percentage: %{type: :number, description: "Percentage of rewards to reinvest", default: 100}
      },
      required: ["token_id"]
    }

  def handler(params, _agent) do
    # Logic:
    # 1. Call harvest on MasterChefV3
    # 2. Call increaseLiquidity on NonfungiblePositionManager
    
    {:ok, %{
      status: "pending_execution",
      steps: [
        %{action: "harvest", args: [params["token_id"]]},
        %{action: "increaseLiquidity", args: [params["token_id"], "REWARD_AMOUNT"]}
      ],
      message: "Collect and reinvest workflow prepared"
    }}
  end
end
