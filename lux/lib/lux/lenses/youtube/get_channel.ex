defmodule Lux.Lenses.YouTube.GetChannel do
  @moduledoc "Get YouTube channel details."

  alias Lux.Integrations.YouTube.Client

  def focus(params, _opts \\ []) do
    channel_id = params[:channel_id] || params["channel_id"]
    username = params[:username] || params["username"]

    qp = %{part: "snippet,statistics,contentDetails,brandingSettings"}
    qp = if channel_id, do: Map.put(qp, :id, channel_id), else: qp
    qp = if username, do: Map.put(qp, :forUsername, username), else: qp

    Client.request(:get, "/channels", %{params: qp, plug: params[:plug]})
    |> format_result()
  end

  defp format_result({:ok, %{"items" => [item | _]}}) do
    snippet = item["snippet"] || %{}
    stats = item["statistics"] || %{}

    {:ok, %{
      id: item["id"],
      title: snippet["title"],
      description: snippet["description"],
      custom_url: snippet["customUrl"],
      published_at: snippet["publishedAt"],
      thumbnail: get_in(snippet, ["thumbnails", "default", "url"]),
      subscriber_count: stats["subscriberCount"],
      video_count: stats["videoCount"],
      view_count: stats["viewCount"],
      uploads_playlist: get_in(item, ["contentDetails", "relatedPlaylists", "uploads"])
    }}
  end

  defp format_result({:ok, %{"items" => []}}), do: {:error, :not_found}
  defp format_result(error), do: error
end
