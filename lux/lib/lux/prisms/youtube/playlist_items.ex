defmodule Lux.Prisms.YouTube.PlaylistItems do
  @moduledoc """
  A prism that normalises a `playlistItems.list` response (YouTube Data API v3)
  into a flat, ordered list of video entries (lux issue #73 — "YouTube Prism
  implementation").

  Pure and deterministic: given the raw `items` list from
  `playlistItems.list?part=snippet,contentDetails` it flattens each entry into a
  uniform `%{video_id, title, position, published_at, channel_title}` record,
  ordered by `position` (the playlist order), and reports the total count plus
  the first and last positions. No network call is made here.

  ## Examples
      iex> PlaylistItems.handler(%{items: [
      ...>   %{snippet: %{title: "First", position: 0, resourceId: %{videoId: "v1"}}}
      ...> ]}, %{name: "Agent"})
      {:ok, %{count: 1, entries: [%{video_id: "v1", position: 0}]}}
  """

  use Lux.Prism,
    name: "YouTube Playlist Items",
    description:
      "Normalises a YouTube playlistItems.list response into an ordered list of video entries",
    input_schema: %{
      type: :object,
      properties: %{
        items: %{
          type: :array,
          description: "playlistItems.list items (each with a snippet and contentDetails)"
        }
      },
      required: ["items"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        count: %{type: :integer, description: "Number of entries"},
        entries: %{
          type: :array,
          description:
            "Ordered entries: %{video_id, title, position, published_at, channel_title}"
        },
        first_position: %{type: :integer, description: "Position of the first entry (0 if empty)"},
        last_position: %{type: :integer, description: "Position of the last entry (0 if empty)"}
      },
      required: ["count", "entries"]
    }

  def handler(params, _agent) do
    items = Map.get(params, :items, [])

    entries =
      items
      |> Enum.map(&normalise/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.position)

    positions = Enum.map(entries, & &1.position)

    result = %{
      count: length(entries),
      entries: entries,
      first_position: List.first(positions) || 0,
      last_position: List.last(positions) || 0
    }

    {:ok, result}
  end

  defp normalise(%{snippet: snippet}) when is_map(snippet) do
    resource = Map.get(snippet, :resourceId, %{})
    video_id = Map.get(resource, :videoId, "")

    %{
      video_id: video_id,
      title: Map.get(snippet, :title, ""),
      position: Map.get(snippet, :position, 0),
      published_at: Map.get(snippet, :publishedAt, ""),
      channel_title: Map.get(snippet, :channelTitle, "")
    }
  end

  defp normalise(_), do: nil
end
