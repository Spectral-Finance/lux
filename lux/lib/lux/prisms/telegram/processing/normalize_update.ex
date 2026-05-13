defmodule Lux.Prisms.Telegram.Processing.NormalizeUpdate do
  @moduledoc """
  Normalizes Telegram updates into a consistent routing envelope.

  Telegram sends different payload shapes for messages, edited messages, and
  callback queries. This prism extracts the common chat, user, thread, reply,
  command, deep-link, and callback fields that agents need before choosing a
  handler.
  """

  use Lux.Prism,
    name: "Normalize Telegram Update",
    description: "Normalizes Telegram message and callback updates for routing and response generation",
    input_schema: %{
      type: :object,
      properties: %{
        update: %{
          type: :object,
          description: "Raw Telegram update payload. The payload itself may also be passed directly."
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        kind: %{type: :string, description: "Normalized update kind"},
        routing_key: %{type: :string, description: "Route key such as command:start or callback:approve"},
        update_id: %{type: :integer, description: "Telegram update identifier"},
        chat_id: %{type: [:string, :integer], description: "Chat identifier"},
        message_id: %{type: :integer, description: "Message identifier"},
        thread_id: %{type: :integer, description: "Topic/thread identifier"},
        reply_to_message_id: %{type: :integer, description: "Message being replied to"},
        text: %{type: :string, description: "Message text or caption"},
        command: %{type: :object, description: "Parsed slash command data"},
        callback_query_id: %{type: :string, description: "Callback query identifier"},
        callback_data: %{type: :string, description: "Raw callback data"}
      },
      required: ["kind", "routing_key"]
    }

  alias Lux.Prisms.Telegram.Processing.ParseCommand

  @doc """
  Normalizes a raw Telegram update payload.
  """
  def handler(params, _agent) when is_map(params) do
    update = value(params, :update) || params

    cond do
      message = value(update, :message) ->
        {:ok, normalize_message(update, message, "message")}

      message = value(update, :edited_message) ->
        {:ok, normalize_message(update, message, "edited_message")}

      callback_query = value(update, :callback_query) ->
        {:ok, normalize_callback_query(update, callback_query)}

      true ->
        {:error, "Unsupported Telegram update"}
    end
  end

  def handler(_params, _agent), do: {:error, "Missing or invalid update"}

  defp normalize_message(update, message, kind) do
    chat = value(message, :chat) || %{}
    user = value(message, :from) || %{}
    reply = value(message, :reply_to_message)
    text = value(message, :text) || value(message, :caption) || ""
    command = command_from_text(text)

    %{
      kind: kind,
      routing_key: message_routing_key(text, command),
      update_id: value(update, :update_id),
      chat_id: value(chat, :id),
      chat_type: value(chat, :type),
      message_id: value(message, :message_id),
      thread_id: value(message, :message_thread_id),
      reply_to_message_id: reply && value(reply, :message_id),
      reply_to_text: reply && (value(reply, :text) || value(reply, :caption)),
      from_user_id: value(user, :id),
      username: value(user, :username),
      text: text,
      command: command,
      deep_link_payload: command && command.deep_link_payload
    }
  end

  defp normalize_callback_query(update, callback_query) do
    user = value(callback_query, :from) || %{}
    message = value(callback_query, :message) || %{}
    chat = value(message, :chat) || %{}
    data = value(callback_query, :data) || ""
    {callback_action, callback_value} = split_callback_data(data)

    %{
      kind: "callback_query",
      routing_key: callback_routing_key(callback_action),
      update_id: value(update, :update_id),
      callback_query_id: value(callback_query, :id),
      callback_data: data,
      callback_action: callback_action,
      callback_value: callback_value,
      chat_id: value(chat, :id),
      chat_type: value(chat, :type),
      message_id: value(message, :message_id),
      thread_id: value(message, :message_thread_id),
      from_user_id: value(user, :id),
      username: value(user, :username),
      text: value(message, :text) || value(message, :caption)
    }
  end

  defp command_from_text(text) do
    case ParseCommand.parse(text) do
      {:ok, command} -> command
      {:error, _reason} -> nil
    end
  end

  defp message_routing_key(_text, %{command: command}), do: "command:#{command}"
  defp message_routing_key(text, _command) when is_binary(text) and text != "", do: "message:text"
  defp message_routing_key(_text, _command), do: "message:non_text"

  defp split_callback_data(""), do: {nil, nil}

  defp split_callback_data(data) do
    case String.split(data, ":", parts: 2) do
      [action, value] -> {action, value}
      [action] -> {action, nil}
    end
  end

  defp callback_routing_key(nil), do: "callback"
  defp callback_routing_key(action), do: "callback:#{action}"

  defp value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp value(_map, _key), do: nil
end
