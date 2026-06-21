defmodule Lux.Lenses.SushiSwap.GetPoolInfo do
  @moduledoc """
  A lens for retrieving SushiSwap V2 liquidity pool information.
  """

  use Lux.Lens,
    name: "SushiSwap Pool Info",
    description: "Fetches pair contract address from SushiSwap V2 Factory",
    schema: %{
      type: :object,
      properties: %{
        token_a: %{
          type: :string,
          description: "Address of Token A",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        token_b: %{
          type: :string,
          description: "Address of Token B",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["token_a", "token_b"]
    }

  alias Lux.Integrations.SushiSwap.Factory

  # SushiSwap V2 Factory on Ethereum
  @factory_address "0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac"

  @impl true
  def handler(params, _agent) do
    case Factory.get_pair(params.token_a, params.token_b, to: @factory_address) do
      {:ok, pair_address} ->
        if pair_address == "0x0000000000000000000000000000000000000000" do
          {:error, "Pool does not exist"}
        else
          {:ok, %{pair_address: pair_address}}
        end
        
      {:error, reason} ->
        {:error, "Failed to fetch pool info: #{inspect(reason)}"}
    end
  end
end
