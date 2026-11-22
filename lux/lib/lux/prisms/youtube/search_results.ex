defmodule Lux.Prisms.YouTube.SearchResults do
  @moduledoc """
  A prism that normalises a `search.list` response (YouTube Data API v3) into a
  flat list of typed search hits (lux issue #73 — "YouTube Prism
  implementation").

  Pure and deterministic: given the raw `items` list from
  `search.list?part=snippet` it flattens each item's `id` map (which is
  polymorphic — `{kind: "video", videoId: "..."}` or
  `{kind: "channel", channelId: "..."}`) into a uniform
  `%{kind, id, title, description, published_at, channel_title}` record, and
  reports a per-kind breakdown. No network call is made here.

  ## Examples
      iex> SearchResults.handler(%{items: [
      ...>   %{id: %{kind: "youtube#video", videoId: "v1"},
      ...>     snippet: %{title: "A", publishedAt: "2024-01-01T00:00:00Z"}}
      ...> ]}, %{name: "Agent"})
      {:ok, %{count: 1, by_kind: %{video: 1}, results: [%{kind: :video, id: "v1"}]}}
  """

  use Lux.Prism,
    name: "YouTube Search Results",
    description:
      "Normalises a YouTube search.list response into a flat list of typed search hits with a per-kind breakdown",
    input_schema: %{
      type: :object,
      properties: %{
        items: %{
          type: :array,
          description: "search.list items (each with an id map and a snippet)"
        }
      },
      required: ["items"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        count: %{type: :integer, description: "Number of normalised results"},
        by_kind: %{type: :object, description: "Count of results per kind (video/channel/playlist)"},
        results: %{
          type: :array,
          description: "Normalised hits: %{kind, id, title, description, published_at, channel_title}"
        }
      },
      required: ["count", "results"]
    }

  def handler(params, _agent) do
    items = Map.get(params, :items, [])

    results =
      items
      |> Enum.map(&normalise/1)
      |> Enum.reject(&is_nil/1)

    by_kind =
      results
      |> Enum.group_by(& &1.kind)
      |> Map.new(fn {kind, list} -> {kind, length(list)} end)

    {:ok, %{count: length(results), by_kind: by_kind, results: results}}
  end

  defp normalise(%{id: id, snippet: snippet}) when is_map(id) and is_map(snippet) do
    {kind, raw_id} = extract_id(id)

    %{
      kind: kind,
      id: raw_id,
      title: Map.get(snippet, :title, ""),
      description: Map.get(snippet, :description, ""),
      published_at: Map.get(snippet, :publishedAt, ""),
      channel_title: Map.get(snippet, :channelTitle, "")
    }
  end

  defp normalise(_), do: nil

  defp extract_id(id) do
    kind = id |> Map.get(:kind, "") |> String.replace_prefix("youtube#", "")
    raw = Map.get(id, :videoId) || Map.get(id, :channelId) || Map.get(id, :playlistId) || ""
    kind_atom = kind_to_atom(kind)
    {kind_atom, raw}
  end

  # Map the Data API's `kind` string to a known atom without leaking atoms
  # (no String.to_atom on user input). Unknown kinds collapse to :unknown.
  defp kind_to_atom("video"), do: :video
  defp kind_to_atom("channel"), do: :channel
  defp kind_to_atom("playlist"), do: :playlist
  defp kind_to_atom(_), do: :unknown
end