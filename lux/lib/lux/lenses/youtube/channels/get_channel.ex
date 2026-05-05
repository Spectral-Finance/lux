defmodule Lux.Lenses.YouTube.Channels.GetChannel do
  @moduledoc "Gets normalized YouTube channel details by channel ID."

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Channel",
    description: "Fetches a YouTube channel by channel ID using YouTube Data API v3",
    url: "https://www.googleapis.com/youtube/v3/channels",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        part: %{type: :string}
      },
      required: ["channel_id"]
    }

  def before_focus(params) do
    params
    |> put_default(:part, "snippet,statistics")
    |> rename(:channel_id, :id)
  end

  def after_focus(%{"items" => [channel | _]}), do: {:ok, normalize_channel(channel)}
  def after_focus(%{"items" => []}), do: {:error, :channel_not_found}
  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(response), do: {:ok, response}

  defp normalize_channel(channel) do
    snippet = channel["snippet"] || %{}
    statistics = channel["statistics"] || %{}

    %{
      id: channel["id"],
      title: snippet["title"],
      description: snippet["description"],
      custom_url: snippet["customUrl"],
      published_at: snippet["publishedAt"],
      subscriber_count: statistics["subscriberCount"],
      video_count: statistics["videoCount"],
      view_count: statistics["viewCount"]
    }
  end

  defp put_default(params, key, value) do
    if Map.has_key?(params, key) or Map.has_key?(params, to_string(key)) do
      params
    else
      Map.put(params, key, value)
    end
  end

  defp rename(params, from, to) do
    string_from = to_string(from)

    cond do
      Map.has_key?(params, from) ->
        {value, params} = Map.pop(params, from)
        Map.put(params, to, value)

      Map.has_key?(params, string_from) ->
        {value, params} = Map.pop(params, string_from)
        Map.put(params, to, value)

      true ->
        params
    end
  end
end
