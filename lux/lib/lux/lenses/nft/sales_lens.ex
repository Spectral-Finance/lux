defmodule Lux.Lenses.NFT.SalesLens do
  @moduledoc """
  Lens for querying recent sales activity across NFT marketplaces.
  """

  use Lux.Lens,
    name: "NFT Recent Sales Lens",
    description: "Fetches recent sales events with price, buyer, seller, and transaction hash",
    url: "https://api.opensea.io/api/v2/events/collection",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        collection_slug: %{
          type: :string,
          description: "Collection slug to query"
        },
        limit: %{
          type: :integer,
          description: "Number of events to retrieve (max 50)",
          default: 30
        }
      },
      required: ["collection_slug"]
    }

  @impl true
  def after_focus(%{"asset_events" => events} = body) do
    parsed_sales =
      Enum.map(events, fn ev ->
        %{
          event_id: ev["id"],
          token_id: get_in(ev, ["nft", "identifier"]) || "0",
          price_raw: get_in(ev, ["payment", "quantity"]) || "0",
          buyer: ev["buyer"] || get_in(ev, ["winner_account", "address"]),
          seller: ev["seller"] || get_in(ev, ["seller_account", "address"]),
          tx_hash: ev["transaction"],
          timestamp: ev["event_timestamp"]
        }
      end)

    {:ok, %{sales: parsed_sales, count: length(parsed_sales), raw_data: body}}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(other) do
    {:ok, other}
  end
end
