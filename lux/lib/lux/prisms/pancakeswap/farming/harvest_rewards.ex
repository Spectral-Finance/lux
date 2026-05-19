defmodule Lux.Prisms.PancakeSwap.Farming.HarvestRewards do
  @moduledoc """
  A prism for harvesting CAKE rewards from a PancakeSwap v3 position.
  """

  alias Lux.Web3.Contract

  use Lux.Prism,
    name: "Harvest PancakeSwap Rewards",
    description: "Harvests CAKE rewards for a specific NFT position ID",
    input_schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string, enum: ["bsc", "ethereum"], default: "bsc"},
        token_id: %{type: :integer, description: "The ID of the position NFT"},
        recipient: %{type: :string, description: "The address to receive the rewards"}
      },
      required: ["token_id", "recipient"]
    }

  def handler(params, _agent) do
    # In a real implementation, we would use Ethers to call harvest(tokenId, recipient)
    # on the MasterChefV3 contract.
    # For now, we return the transaction details that would be needed.
    
    masterchef_address = case params[:chain] || params["chain"] do
      "bsc" -> "0x556397F9083958923595952f283F9950059E4f77"
      "ethereum" -> "0x556397F9083958923595952f283F9950059E4f77"
      _ -> "0x556397F9083958923595952f283F9950059E4f77"
    end

    {:ok, %{
      contract: masterchef_address,
      method: "harvest",
      args: [params["token_id"], params["recipient"]],
      status: "pending_execution",
      message: "Transaction prepared for harvesting rewards"
    }}
  end
end
