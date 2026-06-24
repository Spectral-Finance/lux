defmodule Lux.Lenses.YouTube.Channel.GetChannel do
  @moduledoc """
  A lens for retrieving YouTube channel information and settings.
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Channel",
    description: "Retrieves YouTube channel information and settings",
    url: "#{YouTube.api_base_url()}/channels",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "YouTube channel ID (uses configured channel if omitted)"
        },
        part: %{
          type: :string,
          description: "Comma-separated resource parts",
          default: "snippet,contentDetails,statistics,brandingSettings"
        },
        mine: %{
          type: :boolean,
          description: "Retrieve the authenticated user's channel",
          default: false
        }
      },
      required: []
    }

  @impl true
  def before_focus(params) do
    part = Map.get(params, :part, "snippet,contentDetails,statistics,brandingSettings")
    query_params = [{"part", part}]
    query_params = maybe_add(query_params, :id, Map.get(params, :channel_id, YouTube.channel_id()))
    query_params = maybe_add(query_params, :mine, Map.get(params, :mine))
    %{url: "#{YouTube.api_base_url()}/channels?#{URI.encode_query(query_params)}"}
  end

  @doc """
  Transforms the channel response into a clean format.
  """
  @impl true
  def after_focus(%{"items" => [item | _]}) do
    snippet = item["snippet"] || %{}
    content_details = item["contentDetails"] || %{}
    statistics = item["statistics"] || %{}
    branding = item["brandingSettings"] || %{}

    {:ok, %{
      id: item["id"],
      title: snippet["title"],
      description: snippet["description"],
      custom_url: snippet["customUrl"],
      published_at: snippet["publishedAt"],
      country: snippet["country"],
      subscriber_count: Map.get(statistics, "subscriberCount"),
      video_count: Map.get(statistics, "videoCount"),
      view_count: Map.get(statistics, "viewCount"),
      thumbnail_url: get_thumbnail(snippet["thumbnails"], "high"),
      banner_external_url: get_in(branding, ["image", "bannerExternalUrl"]),
      keywords: get_in(branding, ["channel", "keywords"]),
      managed_by: get_in(branding, ["channel", "managedBy"]),
      unsubscribed_trailer: get_in(branding, ["channel", "unsubscribedTrailer"])
    }}
  end

  def after_focus(%{"items" => []}), do: {:error, "No channel found"}
  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(%{"error" => error}), do: {:error, error}

  defp get_thumbnail(nil, _), do: nil
  defp get_thumbnail(thumbnails, level) when is_map(thumbnails) do
    thumbnails
    |> Map.get(level, %{})
    |> Map.get("url")
  end

  defp maybe_add(params, _key, nil), do: params
  defp maybe_add(params, key, value) when is_boolean(value), do: params ++ [{Atom.to_string(key), to_string(value)}]
  defp maybe_add(params, key, value), do: params ++ [{Atom.to_string(key), to_string(value)}]
end
