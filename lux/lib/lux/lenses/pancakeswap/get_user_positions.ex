defmodule Lux.Lenses.PancakeSwap.GetUserPositions do
  @moduledoc """
  A lens for fetching a user's liquidity positions from PancakeSwap v3 subgraphs.
  """

  alias Lux.Integrations.PancakeSwap

  use Lux.Lens,
    name: "Get PancakeSwap User Positions",
    description: "Fetches all v3 positions for a given user address",
    method: :post,
    headers: PancakeSwap.headers(),
    schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string, enum: ["bsc", "ethereum", "arbitrum", "base"], default: "bsc"},
        user_address: %{type: :string, description: "The wallet address of the user"}
      },
      required: ["user_address"]
    }

  @impl true
  def focus(input \\ %{}, opts \\ []) do
    chain = Map.get(input, :chain, Map.get(input, "chain", "bsc"))
    url = PancakeSwap.subgraph_url(chain)
    
    user_address = Map.get(input, :user_address, Map.get(input, "user_address"))
    
    query = """
    {
      positions(where: {owner: "#{String.downcase(user_address)}"}) {
        id
        pool { id, token0 { symbol }, token1 { symbol } }
        liquidity
        tickLower
        tickUpper
        depositedToken0
        depositedToken1
      }
    }
    """
    
    view()
    |> Map.put(:url, url)
    |> Map.put(:params, %{query: query})
    |> Lux.Lens.focus(opts)
  end

  @impl true
  def after_focus(%{"data" => %{"positions" => positions}}) do
    {:ok, positions}
  end

  def after_focus(error) do
    {:error, error}
  end
end
