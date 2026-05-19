defmodule Lux.Lenses.PancakeSwap.ListFarms do
  @moduledoc """
  A lens for listing yield farms from PancakeSwap MasterChef v3 subgraphs.
  """

  alias Lux.Integrations.PancakeSwap

  use Lux.Lens,
    name: "List PancakeSwap Farms",
    description: "Fetches active farms from PancakeSwap MasterChef v3 subgraph",
    method: :post,
    headers: PancakeSwap.headers(),
    schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string, enum: ["bsc", "ethereum"], default: "bsc"},
        first: %{type: :integer, description: "Number of farms to return", default: 10}
      }
    }

  @impl true
  def focus(input \\ %{}, opts \\ []) do
    chain = Map.get(input, :chain, Map.get(input, "chain", "bsc"))
    url = PancakeSwap.masterchef_subgraph_url(chain)
    
    first = Map.get(input, :first, Map.get(input, "first", 10))

    query = """
    {
      pools(first: #{first}, where: {allocPoint_gt: 0}) {
        id
        v3Pool
        allocPoint
        totalLiquidity
        token0 { symbol }
        token1 { symbol }
      }
    }
    """
    
    view()
    |> Map.put(:url, url)
    |> Map.put(:params, %{query: query})
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
