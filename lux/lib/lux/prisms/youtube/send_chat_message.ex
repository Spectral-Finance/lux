defmodule Lux.Prisms.YouTube.SendChatMessage do
  @moduledoc """
  A prism for sending messages to a YouTube live chat.

  Enables agents to interact with viewers during a live stream
  by posting text messages to the live chat.

  ## Authentication

  Requires OAuth2 token with `youtube` scope.

      config :lux, :api_keys, youtube_oauth_token: "your_oauth2_token"

  ## Examples

      iex> SendChatMessage.handler(%{
      ...>   live_chat_id: "EwAB...",
      ...>   message: "Hello everyone! Thanks for joining!"
      ...> }, %{name: "Agent"})
      {:ok, %{
        message_id: "LCC...",
        text: "Hello everyone! Thanks for joining!",
        author_name: "Channel Name",
        published_at: "2024-01-15T18:05:23.000Z"
      }}
  """

  use Lux.Prism,
    name: "Send YouTube Chat Message",
    description: "Posts a text message to a YouTube live chat",
    input_schema: %{
      type: :object,
      properties: %{
        live_chat_id: %{
          type: :string,
          description: "The live chat ID (from broadcast's snippet.liveChatId)"
        },
        message: %{
          type: :string,
          description: "The message text to send (max 200 characters)",
          maxLength: 200
        }
      },
      required: ["live_chat_id", "message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        message_id: %{type: :string},
        text: %{type: :string},
        author_name: %{type: :string},
        published_at: %{type: :string}
      }
    }

  alias Lux.Integrations.YouTube

  @chat_url "https://www.googleapis.com/youtube/v3/liveChat/messages"

  @impl true
  def handler(params, _agent_ctx) do
    live_chat_id = params["live_chat_id"] || params[:live_chat_id]
    message_text = params["message"] || params[:message]

    if String.length(message_text) > 200 do
      {:error, %{message: "Message exceeds 200 character limit"}}
    else
      oauth_token = Application.get_env(:lux, :api_keys)[:youtube_oauth_token]
      headers = YouTube.headers() ++ [{"Authorization", "Bearer #{oauth_token}"}]

      body = %{
        snippet: %{
          liveChatId: live_chat_id,
          type: "textMessageEvent",
          textMessageDetails: %{
            messageText: message_text
          }
        }
      }

      case Req.post(@chat_url,
        json: body,
        params: %{"part" => "snippet,authorDetails"},
        headers: headers
      ) do
        {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
          snippet = resp_body["snippet"] || %{}
          author = resp_body["authorDetails"] || %{}
          text_details = snippet["textMessageDetails"] || %{}

          {:ok, %{
            message_id: resp_body["id"],
            text: text_details["messageText"],
            author_name: author["displayName"],
            author_channel_id: author["channelId"],
            published_at: snippet["publishedAt"]
          }
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()}

        {:ok, %{body: %{"error" => %{"message" => msg}}}} ->
          {:error, %{message: msg}}

        {:error, reason} ->
          {:error, %{message: inspect(reason)}}
      end
    end
  end
end
