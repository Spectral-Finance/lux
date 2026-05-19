defmodule Lux.Lenses.PancakeSwap.TrackPosition do
  @moduledoc """
  A lens for tracking a specific PancakeSwap v3 position's performance.
  """

  alias Lux.Integrations.PancakeSwap

  use Lux.Lens,
    name: "Track PancakeSwap Position",
    description: "Fetches performance metrics for a specific position ID",
    method: :post,
    headers: PancakeSwap.headers(),
    schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string, enum: ["bsc", "ethereum"], default: "bsc"},
        token_id: %{type: :integer, description: "The ID of the position NFT"}
      },
      required: ["token_id"]
    }

  @impl true
  def focus(input \\ %{}, opts \\ []) do
    chain = Map.get(input, :chain, Map.get(input, "chain", "bsc"))
    url = PancakeSwap.subgraph_url(chain)
    
    token_id = Map.get(input, :token_id, Map.get(input, "token_id"))
    
    query = """
    {
      position(id: "#{token_id}") {
        id
        pool { id, token0 { symbol }, token1 { symbol } }
        liquidity
        depositedToken0
        depositedToken1
        withdrawnToken0
        withdrawnToken1
        collectedFeesToken0
        collectedFeesToken1
      }
    }
    """
    
    view()
    |> Map.put(:url, url)
    |> Map.put(:params, %{query: query})
    |> Lux.Lens.focus(opts)
  end

  @impl true
  def after_focus(%{"data" => %{"position" => position}}) do
    {:ok, position}
  end

  def after_focus(error) do
    {:error, error}
  end
end
