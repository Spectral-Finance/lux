defmodule Lux.Lenses.YouTube.Channels.GetChannel do
  @moduledoc """
  A lens for retrieving YouTube channel details and statistics.

  Returns channel metadata including subscriber count, video count,
  total views, and channel branding.

  ## Authentication

  Uses optional API key via `key` query parameter. Configure in application config:

      config :lux, :api_keys, youtube_api_key: "your_api_key"

  ## Examples

      iex> GetChannel.focus(%{
      ...>   channel_id: "UCxxxxxxxxxxxxxxxxxxxxxx"
      ...> })
      {:ok, %{
        id: "UCxxxxxxxxxxxxxxxxxxxxxx",
        title: "Example Channel",
        description: "A YouTube channel.",
        custom_url: "@example",
        subscriber_count: 150000,
        video_count: 342,
        view_count: 12500000,
        published_at: "2020-01-01T00:00:00.000Z"
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Channel",
    description: "Retrieves channel statistics, metadata, and branding from YouTube",
    url: "https://www.googleapis.com/youtube/v3/channels",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The YouTube channel ID (starts with UC)"
        },
        username: %{
          type: :string,
          description: "The channel's custom URL handle (e.g. 'google')"
        }
      }
    }

  @impl true
  def before_focus(params) do
    base = %{"part" => "snippet,statistics,brandingSettings"}

    cond do
      id = params["channel_id"] || params[:channel_id] ->
        {:ok, Map.put(base, "id", id)}
      username = params["username"] || params[:username] ->
        {:ok, Map.put(base, "forUsername", username)}
      true ->
        {:error, %{message: "Either channel_id or username is required"}}
    end
  end

  @impl true
  def after_focus(%{"items" => [channel | _]}) do
    snippet = channel["snippet"] || %{}
    stats = channel["statistics"] || %{}
    branding = channel["brandingSettings"] || %{}

    result = %{
      id: channel["id"],
      title: snippet["title"],
      description: snippet["description"],
      custom_url: snippet["customUrl"],
      country: snippet["country"],
      published_at: snippet["publishedAt"],
      thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"]),
      banner_url: get_in(branding, ["image", "bannerExternalUrl"]),
      subscriber_count: parse_int(stats["subscriberCount"]),
      video_count: parse_int(stats["videoCount"]),
      view_count: parse_int(stats["viewCount"]),
      hidden_subscriber_count: stats["hiddenSubscriberCount"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, result}
  end

  def after_focus(%{"items" => []}) do
    {:error, %{message: "Channel not found"}}
  end

  def after_focus(%{"error" => %{"message" => msg}}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp parse_int(nil), do: nil
  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, ""} -> i
      _ -> nil
    end
  end
  defp parse_int(i) when is_integer(i), do: i
end
