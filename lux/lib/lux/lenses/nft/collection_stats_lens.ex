defmodule Lux.Lenses.NFT.CollectionStatsLens do
  @moduledoc """
  Lens for querying 24h, 7d, 30d, and all-time NFT collection trading statistics.
  """

  use Lux.Lens,
    name: "NFT Collection Stats Lens",
    description: "Fetches multi-interval trading volume, owner counts, and sales statistics",
    url: "https://api.opensea.io/api/v2/collections",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        collection_slug: %{
          type: :string,
          description: "Collection slug or address"
        }
      },
      required: ["collection_slug"]
    }

  @impl true
  def after_focus(%{"total" => total, "intervals" => intervals} = body) do
    one_day = Enum.find(intervals, %{}, fn i -> i["interval"] == "one_day" end)
    seven_day = Enum.find(intervals, %{}, fn i -> i["interval"] == "seven_day" end)

    {:ok,
     %{
       total_supply: total["supply"] || 0,
       num_owners: total["num_owners"] || 0,
       floor_price_eth: total["floor_price"] || 0.0,
       volume_24h_eth: one_day["volume"] || 0.0,
       sales_24h: one_day["sales"] || 0,
       volume_7d_eth: seven_day["volume"] || 0.0,
       sales_7d: seven_day["sales"] || 0,
       volume_total_eth: total["volume"] || 0.0,
       sales_total: total["sales"] || 0,
       raw_data: body
     }}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(other) do
    {:ok, other}
  end
end
