defmodule Lux.Prisms.YouTube.SendChatMessage do
  @moduledoc "Send a message to a YouTube live chat."

  use Lux.Prism,
    name: "YouTube Send Chat Message",
    description: "Send a text message to a YouTube live chat",
    input_schema: %{
      type: :object,
      properties: %{
        live_chat_id: %{type: :string},
        message: %{type: :string},
        access_token: %{type: :string}
      },
      required: ["live_chat_id", "message", "access_token"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _context) do
    chat_id = params[:live_chat_id] || params["live_chat_id"]
    message = params[:message] || params["message"]
    token = params[:access_token] || params["access_token"]

    body = %{
      snippet: %{
        liveChatId: chat_id,
        type: "textMessageEvent",
        textMessageDetails: %{messageText: message}
      }
    }

    Client.request(:post, "/liveChat/messages?part=snippet", %{
      json: body,
      auth_type: :oauth2,
      access_token: token,
      plug: params[:plug]
    })
    |> case do
      {:ok, data} ->
        {:ok, %{
          message_id: data["id"],
          message: get_in(data, ["snippet", "textMessageDetails", "messageText"]),
          published_at: get_in(data, ["snippet", "publishedAt"])
        }}
      error -> error
    end
  end
end
