defmodule Lux.Prisms.Telegram.ThreadManager do
  @moduledoc """
  Manages Telegram message threads (topics in supergroups).

  Features:
  - Create, close, reopen, delete forum topics
  - Get thread info
  - Reply chain tracking
  """

  use Lux.Prism,
    name: "Telegram Thread Manager",
    description: "Manage message threads and forum topics in Telegram supergroups",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["create_topic", "close_topic", "reopen_topic", "delete_topic", "get_topic"]},
        token: %{type: :string},
        chat_id: %{type: :integer},
        name: %{type: :string},
        message_thread_id: %{type: :integer},
        icon_color: %{type: :integer},
        icon_custom_emoji_id: %{type: :string}
      },
      required: ["action", "token", "chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{result: %{type: :object}}
    }

  alias Lux.Integrations.Telegram.Client

  @impl true
  def handler(params, _agent) do
    action = params["action"] || params[:action]
    token = params["token"] || params[:token]
    chat_id = params["chat_id"] || params[:chat_id]
    plug = params["plug"] || params[:plug]

    case action do
      "create_topic" ->
        body = %{chat_id: chat_id, name: params["name"] || params[:name]}
        |> maybe_put(:icon_color, params["icon_color"] || params[:icon_color])
        |> maybe_put(:icon_custom_emoji_id, params["icon_custom_emoji_id"] || params[:icon_custom_emoji_id])
        Client.request(:post, "/createForumTopic", %{token: token, json: body, plug: plug})

      "close_topic" ->
        thread_id = params["message_thread_id"] || params[:message_thread_id]
        Client.request(:post, "/closeForumTopic", %{token: token, json: %{chat_id: chat_id, message_thread_id: thread_id}, plug: plug})

      "reopen_topic" ->
        thread_id = params["message_thread_id"] || params[:message_thread_id]
        Client.request(:post, "/reopenForumTopic", %{token: token, json: %{chat_id: chat_id, message_thread_id: thread_id}, plug: plug})

      "delete_topic" ->
        thread_id = params["message_thread_id"] || params[:message_thread_id]
        Client.request(:post, "/deleteForumTopic", %{token: token, json: %{chat_id: chat_id, message_thread_id: thread_id}, plug: plug})

      "get_topic" ->
        Client.request(:post, "/getForumTopicIconStickers", %{token: token, json: %{}, plug: plug})

      _ ->
        {:error, "Unknown action: #{action}"}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
