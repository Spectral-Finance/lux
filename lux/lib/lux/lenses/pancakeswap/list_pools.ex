defmodule Lux.Lenses.PancakeSwap.ListPools do
  @moduledoc """
  A lens for listing liquidity pools from PancakeSwap subgraphs.
  """

  alias Lux.Integrations.PancakeSwap

  use Lux.Lens,
    name: "List PancakeSwap Pools",
    description: "Fetches top pools from PancakeSwap subgraph for a given chain",
    method: :post,
    headers: PancakeSwap.headers(),
    schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string, enum: ["bsc", "ethereum", "arbitrum", "base"], default: "bsc"},
        first: %{type: :integer, description: "Number of pools to return", default: 10},
        order_by: %{type: :string, enum: ["totalValueLockedUSD", "volumeUSD"], default: "totalValueLockedUSD"},
        order_direction: %{type: :string, enum: ["asc", "desc"], default: "desc"}
      }
    }

  @impl true
  def before_focus(params) do
    chain = Map.get(params, "chain", "bsc")
    url = PancakeSwap.subgraph_url(chain)
    
    first = Map.get(params, "first", 10)
    order_by = Map.get(params, "order_by", "totalValueLockedUSD")
    order_direction = Map.get(params, "order_direction", "desc")

    query = """
    {
      pools(first: #{first}, orderBy: #{order_by}, orderDirection: #{order_direction}) {
        id
        token0 { symbol, name }
        token1 { symbol, name }
        feeTier
        totalValueLockedUSD
        volumeUSD
      }
    }
    """
    
    # We need to set the URL dynamically based on the chain
    # However, Lux.Lens.focus uses the URL from the struct.
    # We might need to override the URL here if the lens struct doesn't allow it.
    # Actually, the base Lux.Lens.focus uses lens.url.
    # In Lux.Lens.focus/2 (the macro one), it calls Lux.Lens.focus(lens, opts).
    
    %{query: query}
  end

  # Since we need to change the URL dynamically, we override focus/2
  @impl true
  def focus(input \\ %{}, opts \\ []) do
    chain = Map.get(input, :chain, Map.get(input, "chain", "bsc"))
    url = PancakeSwap.subgraph_url(chain)
    
    view()
    |> Map.put(:url, url)
    |> Map.update!(:params, &Map.merge(&1, input))
    |> Map.update!(:params, &before_focus(&1))
    |> Lux.Lens.focus(opts)
  end

  @impl true
  def after_focus(%{"data" => %{"pools" => pools}}) do
    {:ok, pools}
  end

  def after_focus(error) do
    {:error, error}
  end
end
