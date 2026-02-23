defmodule Lux.Lenses.OpenSea.Collections.GetCollection do
  @moduledoc """
  A lens for retrieving NFT collection statistics from the OpenSea API v2.

  This lens provides a simple interface for fetching collection details with:
  - Collection stats (floor price, total volume, owner count)
  - Market data (1-day, 7-day, 30-day stats)
  - Collection metadata (name, description, image, links)
  - Direct OpenSea API error propagation

  ## Authentication

  Uses optional API key via `x-api-key` header. Configure in application config:

      config :lux, :api_keys, opensea: "your_api_key"

  ## Examples

      iex> GetCollection.focus(%{
      ...>   collection_slug: "boredapeyachtclub"
      ...> })
      {:ok, %{
        collection: "boredapeyachtclub",
        name: "Bored Ape Yacht Club",
        description: "A limited NFT collection...",
        image_url: "https://...",
        floor_price: 10.5,
        floor_price_currency: "ETH",
        total_supply: 10000,
        num_owners: 5432,
        total_volume: 987654.32,
        one_day_volume: 234.56,
        seven_day_volume: 1234.78
      }}
  """

  alias Lux.Integrations.OpenSea

  use Lux.Lens,
    name: "Get NFT Collection",
    description: "Retrieves collection statistics and metadata from OpenSea",
    url: "https://api.opensea.io/api/v2/collections/:collection_slug",
    method: :get,
    headers: OpenSea.headers(),
    auth: OpenSea.auth(),
    schema: %{
      type: :object,
      properties: %{
        collection_slug: %{
          type: :string,
          description: "The unique identifier (slug) for the collection on OpenSea",
          pattern: "^[a-z0-9-]+$"
        }
      },
      required: ["collection_slug"]
    }

  @doc """
  Transforms the OpenSea API response into a simplified format.

  ## Examples

      iex> after_focus(%{
      ...>   "collection" => "boredapeyachtclub",
      ...>   "name" => "Bored Ape Yacht Club",
      ...>   "description" => "A limited NFT collection...",
      ...>   "image_url" => "https://example.com/image.png",
      ...>   "stats" => %{
      ...>     "floor_price" => 10.5,
      ...>     "floor_price_symbol" => "ETH",
      ...>     "total_supply" => 10000,
      ...>     "num_owners" => 5432,
      ...>     "total_volume" => 987654.32
      ...>   }
      ...> })
      {:ok, %{
        collection: "boredapeyachtclub",
        name: "Bored Ape Yacht Club",
        floor_price: 10.5,
        floor_price_currency: "ETH",
        total_supply: 10000,
        num_owners: 5432,
        total_volume: 987654.32
      }}
  """
  @impl true
  def after_focus(%{"collection" => collection_slug} = data) do
    stats = data["stats"] || %{}

    result = %{
      collection: collection_slug,
      name: data["name"],
      description: data["description"],
      image_url: data["image_url"],
      banner_image_url: data["banner_image_url"],
      external_url: data["external_url"],
      floor_price: stats["floor_price"] || data["floor_price"],
      floor_price_currency: stats["floor_price_symbol"] || "ETH",
      total_supply: stats["total_supply"] || data["total_supply"],
      num_owners: stats["num_owners"] || data["num_owners"],
      total_volume: stats["total_volume"],
      one_day_volume: stats["one_day_volume"],
      seven_day_volume: stats["seven_day_volume"],
      thirty_day_volume: stats["thirty_day_volume"],
      one_day_sales: stats["one_day_sales"],
      one_day_average_price: stats["one_day_average_price"],
      market_cap: stats["market_cap"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, result}
  end

  def after_focus(%{"errors" => errors}) when is_list(errors) do
    {:error, %{errors: errors}}
  end

  def after_focus(%{"detail" => detail}) do
    {:error, %{detail: detail}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end
end
