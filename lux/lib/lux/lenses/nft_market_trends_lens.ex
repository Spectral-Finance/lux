defmodule Lux.Lenses.NftMarketTrendsLens do
  @moduledoc """
  Lens for fetching NFT market trends and daily volumes from Reservoir.
  """

  use Lux.Lens,
    name: "NFT Market Trends",
    description: "Fetches daily volume and market trends for an NFT collection",
    url: "https://api.reservoir.tools/collections/daily-volumes/v1",
    method: :get,
    headers: [{"accept", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        collection: %{
          type: :string,
          description: "Collection contract address"
        },
        limit: %{
          type: :integer,
          description: "Number of days to return",
          default: 30
        }
      },
      required: ["collection"]
    }

  def add_api_key(lens) do
    case Lux.Config.reservoir_api_key() do
      nil -> lens
      key -> %{lens | headers: lens.headers ++ [{"x-api-key", key}]}
    end
  end

  def before_focus(params) do
    %{
      id: params.collection,
      limit: Map.get(params, :limit, 30)
    }
  end

  @impl true
  def after_focus(%{"collections" => collections}) when is_list(collections) do
    trends =
      Enum.map(collections, fn day_data ->
        %{
          timestamp: day_data["timestamp"],
          volume: day_data["volume"],
          rank: day_data["rank"]
        }
      end)

    {:ok, %{trends: trends}}
  end

  @impl true
  def after_focus(%{"message" => message}) do
    {:error, message}
  end

  @impl true
  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end
