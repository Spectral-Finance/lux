defmodule Lux.Prisms.Uniswap.CollectFees do
  @moduledoc """
  Prism for encoding Uniswap V3 collect fees transactions.
  Encodes NonfungiblePositionManager.collect() parameters.
  """

  use Lux.Prism,
    name: "Uniswap.CollectFees",
    description: "Encodes Uniswap V3 collect transaction calldata",
    input_schema: %{
      type: :object,
      properties: %{
        token_id: %{type: :integer, description: "Uniswap V3 Position NFT token ID"},
        recipient: %{type: :string, description: "Recipient address for collected fees"},
        amount0_max: %{type: :integer, description: "Max amount of token0 to collect"},
        amount1_max: %{type: :integer, description: "Max amount of token1 to collect"},
        network: %{type: :string, description: "Network target", default: "mainnet"}
      },
      required: ["token_id", "recipient"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        to: %{type: :string, description: "NonfungiblePositionManager address"},
        calldata: %{type: :string, description: "Hex encoded collect calldata"}
      },
      required: ["to", "calldata"]
    }

  alias Lux.Integrations.Uniswap

  @impl true
  def handler(input, _ctx) do
    network = Map.get(input, :network, "mainnet")

    Application.put_env(:lux, Uniswap, network: network)

    pm_address = Uniswap.contract_address(:nonfungible_position_manager)

    with {:ok, _} <- Uniswap.validate_address(input.recipient) do
      # 340282366920938463463374607431768211455 is 2^128 - 1
      max_uint128 = 340_282_366_920_938_463_463_374_607_431_768_211_455

      params = %{
        token_id: input.token_id,
        recipient: input.recipient,
        amount0_max: Map.get(input, :amount0_max, max_uint128),
        amount1_max: Map.get(input, :amount1_max, max_uint128)
      }

      calldata = Uniswap.encode_collect(params)
      {:ok, %{to: pm_address, calldata: calldata}}
    end
  end
end
