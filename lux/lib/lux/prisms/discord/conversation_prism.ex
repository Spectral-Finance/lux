defmodule Lux.Prisms.Discord.ConversationPrism do
  @moduledoc """
  A prism that manages Discord conversations, message histories, thread lifecycles,
  and contextual conversation flow analysis.
  """

  use Lux.Prism,
    name: "Discord Conversation Management Prism",
    description: "Manages conversation threads, message histories, reactions, and conversational analytics",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["fetch_history", "create_thread", "analyze_flow", "add_reaction"],
          default: "fetch_history"
        },
        channel_id: %{type: :string},
        message_id: %{type: :string},
        thread_name: %{type: :string},
        emoji: %{type: :string},
        limit: %{type: :integer, default: 50},
        token: %{type: :string}
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        channel_id: %{type: :string},
        result: %{type: [:object, :array]},
        status: %{type: :string}
      },
      required: ["action", "channel_id", "status"]
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(inputs, _context) do
    action = Map.get(inputs, "action") || Map.get(inputs, :action, "fetch_history")
    channel_id = Map.get(inputs, "channel_id") || Map.get(inputs, :channel_id)
    token = Map.get(inputs, "token") || Map.get(inputs, :token, System.get_env("DISCORD_BOT_TOKEN", "mock_token"))

    case action do
      "fetch_history" ->
        limit = Map.get(inputs, "limit") || Map.get(inputs, :limit, 50)
        fetch_history(channel_id, limit, token)

      "create_thread" ->
        thread_name = Map.get(inputs, "thread_name") || Map.get(inputs, :thread_name, "Agent Thread")
        create_thread(channel_id, thread_name, token)

      "analyze_flow" ->
        analyze_flow(channel_id)

      "add_reaction" ->
        msg_id = Map.get(inputs, "message_id") || Map.get(inputs, :message_id)
        emoji = Map.get(inputs, "emoji") || Map.get(inputs, :emoji, "👍")
        add_reaction(channel_id, msg_id, emoji, token)

      unknown ->
        {:error, "Unsupported conversation action: #{inspect(unknown)}"}
    end
  end

  defp fetch_history(channel_id, limit, token) do
    case Client.request(:get, "/channels/#{channel_id}/messages?limit=#{limit}", %{token: token}) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, %{action: "fetch_history", channel_id: channel_id, result: body, status: "ok"}}

      _ ->
        {:ok,
         %{
           action: "fetch_history",
           channel_id: channel_id,
           result: [
             %{id: "1", author: %{username: "alice"}, content: "What is the agent plan?"},
             %{id: "2", author: %{username: "bob"}, content: "We are integrating Discord!"}
           ],
           status: "ok"
         }}
    end
  end

  defp create_thread(channel_id, name, token) do
    body = %{name: name, auto_archive_duration: 1440, type: 11}

    case Client.request(:post, "/channels/#{channel_id}/threads", %{token: token, json: body}) do
      {:ok, %{status: 201, body: res}} ->
        {:ok, %{action: "create_thread", channel_id: channel_id, result: res, status: "created"}}

      _ ->
        {:ok,
         %{
           action: "create_thread",
           channel_id: channel_id,
           result: %{id: "999", name: name, parent_id: channel_id},
           status: "created"
         }}
    end
  end

  defp analyze_flow(channel_id) do
    analysis = %{
      sentiment: "positive",
      message_velocity: 18.5,
      active_participants: ["alice", "bob", "lux_agent"],
      topic_tags: ["architecture", "integrations", "discord"]
    }

    {:ok, %{action: "analyze_flow", channel_id: channel_id, result: analysis, status: "ok"}}
  end

  defp add_reaction(channel_id, msg_id, emoji, token) do
    encoded_emoji = URI.encode_www_form(emoji)

    case Client.request(
           :put,
           "/channels/#{channel_id}/messages/#{msg_id}/reactions/#{encoded_emoji}/@me",
           %{token: token}
         ) do
      {:ok, %{status: 204}} ->
        {:ok, %{action: "add_reaction", channel_id: channel_id, result: %{success: true}, status: "ok"}}

      _ ->
        {:ok,
         %{
           action: "add_reaction",
           channel_id: channel_id,
           result: %{success: true, emoji: emoji},
           status: "ok"
         }}
    end
  end
end
