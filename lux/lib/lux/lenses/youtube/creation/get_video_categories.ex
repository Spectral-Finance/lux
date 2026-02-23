defmodule Lux.Lenses.YouTube.Creation.GetVideoCategories do
  @moduledoc """
  A lens for retrieving available YouTube video categories by region.

  Fetches video categories from the YouTube Data API v3 /videoCategories
  endpoint. Categories define the genre classification for YouTube videos
  and are region-specific.

  ## Authentication

  Uses YouTube Data API key. Configure in application config:

      config :lux, :api_keys, youtube: "your_youtube_api_key"

  ## Examples

      iex> GetVideoCategories.focus(%{"region_code" => "US"})
      {:ok, %{
        categories: [
          %{id: "1", title: "Film & Animation", assignable: true},
          %{id: "2", title: "Autos & Vehicles", assignable: true},
          %{id: "10", title: "Music", assignable: true}
        ],
        region_code: "US",
        count: 3
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Video Categories",
    description: "Retrieves available video categories for a region from the YouTube Data API v3",
    url: "https://www.googleapis.com/youtube/v3/videoCategories",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        region_code: %{
          type: :string,
          description: "ISO 3166-1 alpha-2 region code (e.g., 'US', 'GB', 'DE')"
        },
        hl: %{
          type: :string,
          description: "Language for category titles (BCP-47, e.g., 'en', 'es', 'fr')"
        }
      },
      required: []
    }

  @doc """
  Builds the query parameters for the YouTube videoCategories endpoint.
  """
  @impl true
  def before_focus(params) do
    region_code = params["region_code"] || params[:region_code] || "US"
    hl = params["hl"] || params[:hl] || "en"

    {:ok, %{
      "regionCode" => region_code,
      "hl" => hl,
      "part" => "snippet"
    }}
  end

  @doc """
  Transforms the YouTube API response into structured category data.
  """
  @impl true
  def after_focus(%{"items" => items, "kind" => _kind} = response) when is_list(items) do
    region_code = get_in(response, ["visitorId"]) || "US"

    categories =
      Enum.map(items, fn item ->
        snippet = item["snippet"] || %{}

        %{
          id: item["id"],
          title: snippet["title"],
          assignable: snippet["assignable"] == true,
          channel_id: snippet["channelId"]
        }
      end)

    {:ok, %{
      categories: categories,
      region_code: region_code,
      count: length(categories)
    }}
  end

  def after_focus(%{"items" => items}) when is_list(items) do
    categories =
      Enum.map(items, fn item ->
        snippet = item["snippet"] || %{}

        %{
          id: item["id"],
          title: snippet["title"],
          assignable: snippet["assignable"] == true,
          channel_id: snippet["channelId"]
        }
      end)

    {:ok, %{
      categories: categories,
      region_code: "US",
      count: length(categories)
    }}
  end

  def after_focus(%{"error" => %{"message" => message, "code" => code}}) do
    {:error, %{message: message, code: code}}
  end

  def after_focus(response) do
    {:error, %{message: "Unexpected response", detail: inspect(response)}}
  end
end
