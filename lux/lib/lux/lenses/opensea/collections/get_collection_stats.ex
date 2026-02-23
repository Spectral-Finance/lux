defmodule Lux.Lenses.OpenSea.Collections.GetCollectionStats do
  @moduledoc """
  A lens for retrieving detailed statistics for an NFT collection from the OpenSea API v2.

  This lens provides comprehensive market statistics including:
  - Floor price with currency info
  - Volume across multiple time intervals (1d, 7d, 30d, total)
  - Sales count and average prices per interval
  - Market cap and owner/supply metrics

  ## Authentication

  Uses optional API key via `x-api-key` header. Configure in application config:

      config :lux, :api_keys, opensea: "your_api_key"

  ## Examples

      iex> GetCollectionStats.focus(%{
      ...>   collection_slug: "boredapeyachtclub"
      ...> })
      {:ok, %{
        collection: "boredapeyachtclub",
        floor_price: 10.5,
        floor_price_currency: "ETH",
        total_supply: 10000,
        num_owners: 5432,
        market_cap: 105000.0,
        total_volume: 987654.32,
        intervals: [
          %{interval: "one_day", volume: 234.56, sales: 15, average_price: 15.6},
          %{interval: "seven_day", volume: 1234.78, sales: 84, average_price: 14.7},
          %{interval: "thirty_day", volume: 5678.9, sales: 392, average_price: 14.5}
        ]
      }}
  """

  alias Lux.Integrations.OpenSea

  use Lux.Lens,
    name: "Get NFT Collection Stats",
    description: "Retrieves detailed market statistics for an NFT collection from OpenSea",
    url: "https://api.opensea.io/api/v2/collections/:collection_slug/stats",
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
  Transforms the OpenSea stats API response into a simplified format.

  ## Examples

      iex> after_focus(%{
      ...>   "total" => %{
      ...>     "volume" => 987654.32,
      ...>     "sales" => 12500,
      ...>     "market_cap" => 105000.0,
      ...>     "num_owners" => 5432,
      ...>     "floor_price" => 10.5,
      ...>     "floor_price_symbol" => "ETH",
      ...>     "total_supply" => 10000
      ...>   },
      ...>   "intervals" => []
      ...> })
      {:ok, %{
        floor_price: 10.5,
        floor_price_currency: "ETH",
        total_supply: 10000,
        num_owners: 5432,
        total_volume: 987654.32,
        intervals: []
      }}
  """
  @impl true
  def after_focus(%{"total" => total} = data) do
    intervals = data["intervals"] || []

    result = %{
      floor_price: total["floor_price"],
      floor_price_currency: total["floor_price_symbol"] || "ETH",
      total_supply: total["total_supply"],
      num_owners: total["num_owners"],
      market_cap: total["market_cap"],
      total_volume: total["volume"],
      total_sales: total["sales"],
      average_price: total["average_price"],
      intervals: Enum.map(intervals, &format_interval/1)
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

  defp format_interval(interval) do
    %{
      interval: interval["interval"],
      volume: interval["volume"],
      volume_diff: interval["volume_diff"],
      volume_change: interval["volume_change"],
      sales: interval["sales"],
      sales_diff: interval["sales_diff"],
      average_price: interval["average_price"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
