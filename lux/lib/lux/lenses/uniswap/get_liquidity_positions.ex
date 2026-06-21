defmodule Lux.Lenses.Uniswap.GetLiquidityPositions do
  @moduledoc """
  Lens for fetching liquidity positions owned by an address from Uniswap V3.

  Returns a list of positions with details including token pair, fee tier,
  tick range, liquidity amount, and uncollected fees.

  ## Examples

      Lux.Lenses.Uniswap.GetLiquidityPositions.focus(%{
        owner: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        network: "mainnet"
      })
  """

  use Lux.Lens,
    name: "Uniswap.GetLiquidityPositions",
    description: "Fetches all Uniswap V3 liquidity positions owned by an address",
    url: "https://eth-mainnet.g.alchemy.com/v2",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        owner: %{
          type: :string,
          description: "Owner address to query positions for"
        },
        network: %{
          type: :string,
          description: "Network to query (mainnet, goerli, sepolia, arbitrum, optimism, polygon, base)",
          default: "mainnet"
        }
      },
      required: ["owner"]
    }

  alias Lux.Integrations.Uniswap

  @impl true
  def after_focus(_response) do
    {:ok, %{}}
  end

  @doc """
  Custom focus implementation that queries Uniswap V3 on-chain data.
  """
  def focus(params, _opts) do
    owner = Map.fetch!(params, :owner)
    network = Map.get(params, :network, "mainnet")

    # Configure network
    Application.put_env(:lux, Uniswap, network: network)

    with {:ok, _} <- Uniswap.validate_address(owner),
         {:ok, positions} <- Uniswap.get_liquidity_positions(owner) do
      {:ok, %{positions: positions}}
    end
  end
end
