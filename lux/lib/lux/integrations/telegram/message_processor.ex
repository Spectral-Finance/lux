defmodule Lux.Integrations.Telegram.MessageProcessor do
  @moduledoc """
  Offline Telegram update processing utilities.

  This module classifies Bot API updates, extracts command parameters, normalizes
  message/thread/reply context, escapes MarkdownV2 and HTML, parses deep-link
  payloads, and decodes callback query data. It performs no network calls.
  """

  @update_fields [
    :message,
    :edited_message,
    :channel_post,
    :edited_channel_post,
    :callback_query,
    :inline_query,
    :chosen_inline_result,
    :poll,
    :poll_answer,
    :my_chat_member,
    :chat_member,
    :chat_join_request
  ]

  @message_types [
    :text,
    :photo,
    :video,
    :audio,
    :voice,
    :video_note,
    :document,
    :sticker,
    :animation,
    :contact,
    :location,
    :venue,
    :poll,
    :dice,
    :game,
    :invoice,
    :successful_payment,
    :unknown
  ]

  @doc """
  Processes one Telegram update into agent-ready routing data.
  """
  @spec process_update(map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def process_update(update, opts \\ [])

  def process_update(update, opts) when is_map(update) do
    bot_username = opts |> Keyword.get(:bot_username, "") |> normalize_bot_username()
    update_type = update_type(update)
    payload = update_payload(update, update_type)
    message = message_payload(payload, update_type)
    text = message_text(message, payload, update_type)

    {:ok,
     %{
       update_id: value(update, :update_id, nil),
       update_type: update_type,
       message_type: message_type(message, payload, update_type),
       chat: chat_context(message),
       from: user_context(payload, message),
       thread: thread_context(message),
       reply: reply_context(message),
       text: text,
       command: parse_command(text, bot_username),
       deep_link: parse_deep_link(text),
       callback: callback_context(payload, update_type),
       formatting: %{
         markdown_v2: escape_markdown_v2(text),
         html: escape_html(text)
       },
       route: route(update_type, message, payload, text, bot_username)
     }}
  end

  def process_update(_update, _opts), do: {:error, "Expected a Telegram update map"}

  @doc """
  Parses a Telegram slash command with optional bot mention and arguments.
  """
  @spec parse_command(String.t(), String.t()) :: map() | nil
  def parse_command(text, bot_username \\ "")

  def parse_command(text, bot_username) when is_binary(text) do
    bot_username = normalize_bot_username(bot_username)

    case Regex.run(~r/^\/([a-zA-Z0-9_]+)(?:@([a-zA-Z0-9_]+))?(?:\s+(.*))?$/s, String.trim(text)) do
      [_, command, mention, args] ->
        mention = normalize_bot_username(mention)

        if mention in ["", bot_username] do
          %{
            command: String.downcase(command),
            bot_mention: mention,
            raw_args: args || "",
            args: parse_args(args || "")
          }
        end

      [_, command, mention] ->
        mention = normalize_bot_username(mention)

        if mention in ["", bot_username] do
          %{command: String.downcase(command), bot_mention: mention, raw_args: "", args: []}
        end

      _ ->
        nil
    end
  end

  def parse_command(_text, _bot_username), do: nil

  @doc """
  Escapes text for Telegram MarkdownV2 parse mode.
  """
  @spec escape_markdown_v2(String.t()) :: String.t()
  def escape_markdown_v2(text) when is_binary(text) do
    Regex.replace(~r/([_*\[\]()~`>#+\-=|{}.!])/, text, "\\\\\\1")
  end

  def escape_markdown_v2(_text), do: ""

  @doc """
  Escapes text for Telegram HTML parse mode.
  """
  @spec escape_html(String.t()) :: String.t()
  def escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  def escape_html(_text), do: ""

  @doc """
  Parses `/start payload` deep-link payloads.
  """
  @spec parse_deep_link(String.t()) :: map() | nil
  def parse_deep_link(text) do
    case parse_command(text || "") do
      %{command: "start", raw_args: payload} when payload != "" ->
        %{
          payload: payload,
          parts: String.split(payload, ["_", "-", ":"], trim: true)
        }

      _ ->
        nil
    end
  end

  @doc """
  Returns the supported message type names.
  """
  def message_types, do: @message_types

  defp update_type(update) do
    Enum.find(@update_fields, :unknown, fn field -> not is_nil(value(update, field, nil)) end)
  end

  defp update_payload(_update, :unknown), do: %{}
  defp update_payload(update, type), do: value(update, type, %{})

  defp message_payload(payload, type)
       when type in [:message, :edited_message, :channel_post, :edited_channel_post],
       do: payload

  defp message_payload(payload, :callback_query), do: value(payload, :message, %{})
  defp message_payload(_payload, _type), do: %{}

  defp message_text(message, payload, :callback_query),
    do: string_value(payload, :data, string_value(message, :text, ""))

  defp message_text(message, _payload, _type),
    do: string_value(message, :text, string_value(message, :caption, ""))

  defp message_type(_message, payload, :callback_query) do
    if value(payload, :data, nil), do: :callback_query, else: :unknown
  end

  defp message_type(message, _payload, _type) do
    cond do
      string_value(message, :text, "") != "" -> :text
      string_value(message, :caption, "") != "" -> media_type(message)
      true -> media_type(message)
    end
  end

  defp media_type(message) do
    Enum.find(@message_types, :unknown, fn type ->
      type != :text and type != :unknown and not is_nil(value(message, type, nil))
    end)
  end

  defp chat_context(message) do
    chat = value(message, :chat, %{})

    %{
      id: value(chat, :id, nil),
      type: value(chat, :type, nil),
      title: value(chat, :title, nil),
      username: value(chat, :username, nil)
    }
  end

  defp user_context(payload, message) do
    user = value(payload, :from, value(message, :from, %{}))

    %{
      id: value(user, :id, nil),
      is_bot: value(user, :is_bot, false),
      username: value(user, :username, nil),
      first_name: value(user, :first_name, nil),
      language_code: value(user, :language_code, nil)
    }
  end

  defp thread_context(message) do
    %{
      message_id: value(message, :message_id, nil),
      thread_id: value(message, :message_thread_id, nil),
      date: value(message, :date, nil)
    }
  end

  defp reply_context(message) do
    case value(message, :reply_to_message, nil) do
      reply when is_map(reply) ->
        %{
          message_id: value(reply, :message_id, nil),
          text: string_value(reply, :text, string_value(reply, :caption, "")),
          from: user_context(reply, reply)
        }

      _ ->
        nil
    end
  end

  defp callback_context(payload, :callback_query) do
    data = string_value(payload, :data, "")

    %{
      id: value(payload, :id, nil),
      data: data,
      parts: parse_callback_parts(data),
      message_id: payload |> value(:message, %{}) |> value(:message_id, nil)
    }
  end

  defp callback_context(_payload, _type), do: nil

  defp parse_callback_parts(data) do
    case String.split(data || "", ":", parts: 3) do
      [namespace, action, id] -> %{namespace: namespace, action: action, id: id}
      [action, id] -> %{namespace: nil, action: action, id: id}
      [action] when action != "" -> %{namespace: nil, action: action, id: nil}
      _ -> %{}
    end
  end

  defp route(:callback_query, _message, _payload, _text, _bot_username),
    do: %{action: :handle_callback, target: :callback_query}

  defp route(type, message, _payload, text, bot_username) do
    cond do
      command = parse_command(text, bot_username) ->
        %{action: :command, target: command.command}

      value(message, :reply_to_message, nil) ->
        %{action: :reply, target: :thread}

      type in [:channel_post, :edited_channel_post] ->
        %{action: :channel_post, target: :broadcast}

      true ->
        %{action: :message, target: message_type(message, %{}, type)}
    end
  end

  defp parse_args(args) do
    args
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(fn arg ->
      case String.split(arg, "=", parts: 2) do
        [key, value] -> %{key: key, value: value}
        [value] -> value
      end
    end)
  end

  defp value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, to_string(key), default))

  defp value(_map, _key, default), do: default

  defp string_value(map, key, default) do
    case value(map, key, default) do
      value when is_binary(value) -> value
      value when is_integer(value) -> Integer.to_string(value)
      value when is_float(value) -> Float.to_string(value)
      _ -> default
    end
  end

  defp normalize_bot_username(nil), do: ""

  defp normalize_bot_username(username),
    do: username |> to_string() |> String.trim_leading("@") |> String.downcase()
end
