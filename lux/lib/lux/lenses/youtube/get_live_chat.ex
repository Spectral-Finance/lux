defmodule Lux.Lenses.YouTube.GetLiveChat do
  @moduledoc "Get live chat messages from a YouTube live stream."

  alias Lux.Integrations.YouTube.Client

  def focus(params, _opts \\ []) do
    chat_id = params[:live_chat_id] || params["live_chat_id"]
    page_token = params[:page_token] || params["page_token"]

    qp = %{part: "snippet,authorDetails", liveChatId: chat_id}
    qp = if page_token, do: Map.put(qp, :pageToken, page_token), else: qp

    Client.request(:get, "/liveChat/messages", %{
      params: qp,
      auth_type: :oauth2,
      access_token: params[:access_token],
      plug: params[:plug]
    })
    |> format_results()
  end

  defp format_results({:ok, %{"items" => items} = body}) do
    messages = Enum.map(items, fn item ->
      snippet = item["snippet"] || %{}
      author = item["authorDetails"] || %{}

      %{
        id: item["id"],
        message: get_in(snippet, ["displayMessage"]) || get_in(snippet, ["textMessageDetails", "messageText"]),
        author_name: author["displayName"],
        author_channel_id: author["channelId"],
        is_moderator: author["isChatModerator"],
        is_owner: author["isChatOwner"],
        published_at: snippet["publishedAt"]
      }
    end)

    {:ok, %{
      messages: messages,
      next_page_token: body["nextPageToken"],
      polling_interval_ms: body["pollingIntervalMillis"]
    }}
  end
  defp format_results(error), do: error
end
