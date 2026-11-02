defmodule Lux.Prisms.Discord.MessageManagementPrism do
  @moduledoc """
  Core Prism for Discord message management operations:
  - Creating and sending messages
  - Editing existing messages
  - Single and bulk message deletion
  - Message history tracking
  """

  use Lux.Prism,
    name: "Discord Message Management Prism",
    description: "Performs message creation, editing, deletion, bulk deletion, and history tracking in Discord channels",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "create_message",
            "edit_message",
            "delete_message",
            "bulk_delete",
            "get_history"
          ],
          description: "Message management action to perform"
        },
        payload: %{
          type: :object,
          description: "Action-specific parameters and options"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: :object}
      },
      required: ["action", "result"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action", "create_message")
    payload = Map.get(input, :payload) || Map.get(input, "payload", %{})

    case execute_action(action, payload) do
      {:ok, result} ->
        {:ok, %{action: action, result: result}}

      {:error, reason} ->
        {:error, "MessageManagementPrism error on '#{action}': #{inspect(reason)}"}
    end
  end

  defp execute_action("create_message", payload) do
    channel_id = Map.get(payload, :channel_id, Map.get(payload, "channel_id"))
    content = Map.get(payload, :content, Map.get(payload, "content", ""))
    embeds = Map.get(payload, :embeds, Map.get(payload, "embeds"))
    opts = extract_client_opts(payload)

    body = %{"content" => content}
    body = if embeds, do: Map.put(body, "embeds", embeds), else: body

    Client.request(:post, "/channels/#{channel_id}/messages", Map.put(opts, :json, body))
  end

  defp execute_action("edit_message", payload) do
    channel_id = Map.get(payload, :channel_id, Map.get(payload, "channel_id"))
    message_id = Map.get(payload, :message_id, Map.get(payload, "message_id"))
    content = Map.get(payload, :content, Map.get(payload, "content", ""))
    opts = extract_client_opts(payload)

    body = %{"content" => content}
    Client.request(:patch, "/channels/#{channel_id}/messages/#{message_id}", Map.put(opts, :json, body))
  end

  defp execute_action("delete_message", payload) do
    channel_id = Map.get(payload, :channel_id, Map.get(payload, "channel_id"))
    message_id = Map.get(payload, :message_id, Map.get(payload, "message_id"))
    opts = extract_client_opts(payload)

    case Client.request(:delete, "/channels/#{channel_id}/messages/#{message_id}", opts) do
      {:ok, _} -> {:ok, %{deleted: true, message_id: message_id}}
      error -> error
    end
  end

  defp execute_action("bulk_delete", payload) do
    channel_id = Map.get(payload, :channel_id, Map.get(payload, "channel_id"))
    messages = Map.get(payload, :messages, Map.get(payload, "messages", []))
    opts = extract_client_opts(payload)

    body = %{"messages" => messages}
    case Client.request(:post, "/channels/#{channel_id}/messages/bulk-delete", Map.put(opts, :json, body)) do
      {:ok, _} -> {:ok, %{bulk_deleted: true, count: length(messages)}}
      error -> error
    end
  end

  defp execute_action("get_history", payload) do
    channel_id = Map.get(payload, :channel_id, Map.get(payload, "channel_id"))
    limit = Map.get(payload, :limit, Map.get(payload, "limit", 50))
    opts = extract_client_opts(payload)

    Client.request(:get, "/channels/#{channel_id}/messages?limit=#{limit}", opts)
  end

  defp execute_action(unknown, _payload) do
    {:error, "Unknown action: #{unknown}"}
  end

  defp extract_client_opts(payload) do
    opts = %{}

    opts =
      case Map.get(payload, :token, Map.get(payload, "token")) do
        nil -> opts
        token -> Map.put(opts, :token, token)
      end

    case Map.get(payload, :plug, Map.get(payload, "plug")) do
      nil -> opts
      plug -> Map.put(opts, :plug, plug)
    end
  end
end
