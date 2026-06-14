defmodule Lux.Prisms.YouTube.YouTubeChatPrism do
  @moduledoc """
  A prism for managing YouTube live chat - read messages, send messages, ban users.
  """

  use Lux.Prism,
    name: "YouTube Live Chat Manager",
    description: "Manages YouTube live chat messages and moderation",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["list_messages", "send_message", "delete_message", "ban_user"]},
        live_chat_id: %{type: :string},
        message_id: %{type: :string},
        message: %{type: :string},
        channel_id: %{type: :string},
        max_results: %{type: :integer, default: 50}
      },
      required: ["action", "live_chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        messages: %{type: :array},
        message: %{type: :object}
      },
      required: ["status"]
    }

  require Logger

  @api "https://www.googleapis.com/youtube/v3"

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key() do
      case input.action do
        "list_messages"  -> list_messages(api_key, input)
        "send_message"   -> send_message(api_key, input)
        "delete_message" -> delete_message(api_key, input.message_id)
        "ban_user"       -> ban_user(api_key, input)
        _                -> {:error, "Unknown action: #{input.action}"}
      end
    end
  end

  defp get_api_key do
    key = Lux.Config.get(:youtube_api_key) || System.get_env("YOUTUBE_API_KEY")
    if key, do: {:ok, key}, else: {:error, "YouTube API key not configured"}
  rescue
    _ -> {:error, "YouTube API key not configured"}
  end

  defp list_messages(api_key, input) do
    case Req.get("#{@api}/liveChat/messages",
      params: %{
        liveChatId: input.live_chat_id,
        part: "snippet,authorDetails",
        maxResults: Map.get(input, :max_results, 50),
        key: api_key
      }
    ) do
      {:ok, %{status: 200, body: body}} ->
        messages = Enum.map(body["items"] || [], &parse_message/1)
        {:ok, %{status: "success", messages: messages, next_page_token: body["nextPageToken"]}}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp send_message(api_key, input) do
    body = %{
      snippet: %{
        liveChatId: input.live_chat_id,
        type: "textMessageEvent",
        textMessageDetails: %{messageText: input.message}
      }
    }
    case Req.post("#{@api}/liveChat/messages?part=snippet&key=#{api_key}", json: body) do
      {:ok, %{status: 200, body: b}} -> {:ok, %{status: "success", message: parse_message(b)}}
      {:ok, %{status: s, body: b}}   -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r}                    -> {:error, inspect(r)}
    end
  end

  defp delete_message(api_key, message_id) do
    case Req.delete("#{@api}/liveChat/messages?id=#{message_id}&key=#{api_key}") do
      {:ok, %{status: 204}} -> {:ok, %{status: "success", message: "Message deleted"}}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp ban_user(api_key, input) do
    body = %{
      snippet: %{
        liveChatId: input.live_chat_id,
        type: "permanent",
        bannedUserDetails: %{channelId: input.channel_id}
      }
    }
    case Req.post("#{@api}/liveChat/bans?part=snippet&key=#{api_key}", json: body) do
      {:ok, %{status: 200, body: b}} -> {:ok, %{status: "success", ban: b}}
      {:ok, %{status: s, body: b}}   -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r}                    -> {:error, inspect(r)}
    end
  end

  defp parse_message(item) do
    %{
      id: item["id"],
      text: get_in(item, ["snippet", "textMessageDetails", "messageText"]),
      author: get_in(item, ["authorDetails", "displayName"]),
      author_channel: get_in(item, ["authorDetails", "channelId"]),
      published_at: get_in(item, ["snippet", "publishedAt"])
    }
  end
end
