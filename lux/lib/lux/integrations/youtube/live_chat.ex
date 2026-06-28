defmodule Lux.Integrations.YouTube.LiveChat do
  @moduledoc """
  Handles YouTube Live Chat interaction.
  """

  alias Lux.Integrations.YouTube.Client

  @doc """
  Lists live chat messages for a given live chat ID.
  Accepts a `page_token` for pagination.
  """
  def list_messages(live_chat_id, page_token \\ nil, config \\ Client.default_config()) do
    query_params = [
      liveChatId: live_chat_id,
      part: "id,snippet,authorDetails"
    ]

    query_params =
      if page_token do
        Keyword.put(query_params, :pageToken, page_token)
      else
        query_params
      end

    Client.get("/liveChat/messages", query_params, config)
  end

  @doc """
  Inserts a new message into a live chat.
  """
  def send_message(live_chat_id, message_text, config \\ Client.default_config()) do
    query_params = [part: "snippet"]

    body = %{
      snippet: %{
        liveChatId: live_chat_id,
        type: "textMessageEvent",
        textMessageDetails: %{
          messageText: message_text
        }
      }
    }

    Client.post("/liveChat/messages", body, query_params, config)
  end
end
