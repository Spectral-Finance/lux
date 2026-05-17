defmodule Lux.Lenses.YouTube.Live.ListChatMessages do
  @moduledoc """
  Reads live chat messages from a YouTube live broadcast.
  """

  alias Lux.Integrations.YouTube
  alias Lux.Integrations.YouTube.LiveStream

  use Lux.Lens,
    name: "List YouTube Live Chat Messages",
    description: "Lists and normalizes YouTube live chat messages for an active liveChatId",
    url: "https://www.googleapis.com/youtube/v3/liveChat/messages",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        live_chat_id: %{
          type: :string,
          description: "The liveChatId from a YouTube live broadcast"
        },
        part: %{
          type: :string,
          description: "Comma-separated liveChatMessage resource parts",
          default: "snippet,authorDetails"
        },
        page_token: %{
          type: :string,
          description: "Pagination token from the previous response"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of chat messages",
          minimum: 1,
          maximum: 200,
          default: 100
        }
      },
      required: ["live_chat_id"]
    }

  def before_focus(params) do
    params
    |> Map.put_new(:part, "snippet,authorDetails")
    |> rename(:live_chat_id, :liveChatId)
    |> rename(:page_token, :pageToken)
    |> rename(:max_results, :maxResults)
  end

  @impl true
  def after_focus(%{"items" => items} = response) do
    {:ok,
     %{
       messages: Enum.map(items, &LiveStream.normalize_chat_message/1),
       next_page_token: response["nextPageToken"],
       polling_interval_millis: response["pollingIntervalMillis"]
     }}
  end

  def after_focus(%{"error" => error}), do: {:error, error}

  defp rename(params, from, to) do
    case Map.pop(params, from) do
      {nil, params} -> params
      {value, params} -> Map.put(params, to, value)
    end
  end
end
