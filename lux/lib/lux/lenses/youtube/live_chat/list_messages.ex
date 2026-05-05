defmodule Lux.Lenses.YouTube.LiveChat.ListMessages do
  @moduledoc "Lists messages from a YouTube live chat."

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Live Chat Messages",
    description: "Lists live chat messages for a YouTube live broadcast",
    url: "https://www.googleapis.com/youtube/v3/liveChat/messages",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        liveChatId: %{type: :string, description: "Active live chat ID"},
        maxResults: %{type: :integer, minimum: 1, maximum: 200}
      },
      required: ["liveChatId"]
    }

  def before_focus(params) do
    params
    |> maybe_rename(:live_chat_id, :liveChatId)
    |> maybe_rename(:page_token, :pageToken)
    |> maybe_rename(:max_results, :maxResults)
    |> Map.put_new(:part, "id,snippet,authorDetails")
  end

  def after_focus(%{"items" => items} = response) when is_list(items) do
    {:ok,
     %{
       next_page_token: response["nextPageToken"],
       polling_interval_millis: response["pollingIntervalMillis"],
       messages: Enum.map(items, &normalize_message/1)
     }}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(response), do: {:ok, response}

  defp normalize_message(item) do
    snippet = item["snippet"] || %{}
    author = item["authorDetails"] || %{}

    %{
      id: item["id"],
      message: snippet["displayMessage"],
      published_at: snippet["publishedAt"],
      author_channel_id: author["channelId"],
      author_name: author["displayName"]
    }
  end

  defp maybe_rename(params, from, to) do
    case Map.pop(params, from) do
      {nil, params} -> params
      {value, params} -> Map.put(params, to, value)
    end
  end
end
