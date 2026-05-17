defmodule Lux.Lenses.YouTube.Channels.ListChannels do
  @moduledoc """
  Lists YouTube channels visible to the authenticated user or by explicit channel ids.
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Channels",
    description: "Lists YouTube channel metadata using the YouTube Data API v3",
    url: "https://www.googleapis.com/youtube/v3/channels",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        part: %{
          type: :string,
          description: "Comma-separated channel resource parts",
          default: "snippet,contentDetails,statistics"
        },
        mine: %{
          type: :boolean,
          description: "Whether to list channels owned by the authenticated user"
        },
        id: %{
          type: :string,
          description: "Comma-separated YouTube channel ids"
        },
        for_username: %{
          type: :string,
          description: "Legacy YouTube username lookup"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of channels to return",
          minimum: 1,
          maximum: 50,
          default: 5
        }
      },
      required: []
    }

  def before_focus(params) do
    params
    |> Map.put_new(:part, "snippet,contentDetails,statistics")
    |> rename(:for_username, :forUsername)
    |> rename(:max_results, :maxResults)
  end

  @impl true
  def after_focus(%{"items" => items}) do
    {:ok, Enum.map(items, &normalize_channel/1)}
  end

  def after_focus(%{"error" => error}), do: {:error, error}

  defp normalize_channel(%{"id" => id} = item) do
    snippet = item["snippet"] || %{}
    statistics = item["statistics"] || %{}
    content_details = item["contentDetails"] || %{}

    %{
      id: id,
      title: snippet["title"],
      description: snippet["description"],
      custom_url: snippet["customUrl"],
      published_at: snippet["publishedAt"],
      uploads_playlist_id: get_in(content_details, ["relatedPlaylists", "uploads"]),
      view_count: parse_count(statistics["viewCount"]),
      subscriber_count: parse_count(statistics["subscriberCount"]),
      video_count: parse_count(statistics["videoCount"])
    }
  end

  defp rename(params, from, to) do
    case Map.pop(params, from) do
      {nil, params} -> params
      {value, params} -> Map.put(params, to, value)
    end
  end

  defp parse_count(nil), do: nil
  defp parse_count(value) when is_integer(value), do: value
  defp parse_count(value) when is_binary(value), do: String.to_integer(value)
end
