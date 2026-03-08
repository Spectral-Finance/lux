defmodule Lux.Lenses.YouTube.SearchVideos do
  @moduledoc "Search YouTube videos."

  alias Lux.Integrations.YouTube.Client

  def focus(params, _opts \\ []) do
    query = params[:query] || params["query"]
    max_results = params[:max_results] || params["max_results"] || 10
    order = params[:order] || params["order"] || "relevance"
    type = params[:type] || params["type"] || "video"

    Client.request(:get, "/search", %{
      params: %{
        part: "snippet",
        q: query,
        maxResults: max_results,
        order: order,
        type: type
      },
      plug: params[:plug]
    })
    |> format_results()
  end

  defp format_results({:ok, %{"items" => items}}) do
    {:ok, %{videos: Enum.map(items, fn item ->
      %{
        id: get_in(item, ["id", "videoId"]) || get_in(item, ["id", "channelId"]),
        title: get_in(item, ["snippet", "title"]),
        description: get_in(item, ["snippet", "description"]),
        channel_title: get_in(item, ["snippet", "channelTitle"]),
        published_at: get_in(item, ["snippet", "publishedAt"]),
        thumbnail: get_in(item, ["snippet", "thumbnails", "default", "url"])
      }
    end)}}
  end
  defp format_results(error), do: error
end
