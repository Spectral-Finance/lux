defmodule Lux.Integrations.Telegram.MessageProcessing do
  @moduledoc """
  Pure Telegram update/message processing helpers.

  These helpers intentionally avoid Bot API calls. They normalize incoming Bot API
  update maps into small, agent-friendly structures that can be used by prisms,
  beams, routers, or tests without requiring a Telegram token.
  """

  @command_regex ~r/^\/(?<command>[A-Za-z0-9_]{1,64})(?:@(?<bot>[A-Za-z0-9_]+))?(?:\s+(?<args>[\s\S]*))?$/u
  @markdown_v2_specials ~r/([_\*\[\]\(\)~`>#+\-=|{}.!\\])/u

  @type command :: %{
          command: String.t(),
          args: [String.t()],
          raw_args: String.t(),
          bot: String.t() | nil,
          addressed?: boolean()
        }

  @type analysis :: %{
          update_id: integer() | nil,
          type: atom(),
          message: map() | nil,
          chat_id: integer() | String.t() | nil,
          user_id: integer() | nil,
          text: String.t() | nil,
          command: command() | nil,
          thread: map(),
          reply: map() | nil,
          callback_query: map() | nil,
          deep_link: map() | nil,
          entities: list(map())
        }

  @doc """
  Classifies and normalizes a Telegram Bot API update map.
  """
  @spec analyze_update(map(), keyword()) :: analysis()
  def analyze_update(update, opts \\ []) when is_map(update) do
    bot_username = Keyword.get(opts, :bot_username)
    {type, message} = extract_message(update)
    text = message_text(message)

    %{
      update_id: get_value(update, "update_id"),
      type: type,
      message: message,
      chat_id: get_in_value(message, ["chat", "id"]),
      user_id: user_id(update, message),
      text: text,
      command: parse_command(text, bot_username),
      thread: thread_context(message),
      reply: reply_context(message),
      callback_query: callback_query_context(update),
      deep_link: deep_link_payload(text, bot_username),
      entities: get_value(message || %{}, "entities", [])
    }
  end

  @doc """
  Parses slash commands, including optional bot mentions and quoted arguments.

      iex> parse_command("/trade@LuxBot buy ETH 1", "LuxBot")
      %{command: "trade", args: ["buy", "ETH", "1"], raw_args: "buy ETH 1", bot: "LuxBot", addressed?: true}
  """
  @spec parse_command(String.t() | nil, String.t() | nil) :: command() | nil
  def parse_command(text, bot_username \\ nil)
  def parse_command(nil, _bot_username), do: nil

  def parse_command(text, bot_username) when is_binary(text) do
    trimmed = String.trim(text)

    case Regex.named_captures(@command_regex, trimmed) do
      %{"command" => command, "bot" => bot, "args" => raw_args} ->
        normalized_bot = blank_to_nil(bot)
        raw_args = raw_args || ""

        %{
          command: command,
          args: split_args(raw_args),
          raw_args: raw_args,
          bot: normalized_bot,
          addressed?: addressed?(normalized_bot, bot_username)
        }

      _ ->
        nil
    end
  end

  @doc """
  Escapes text for Telegram MarkdownV2 parse mode.
  """
  @spec escape_markdown_v2(String.t() | nil) :: String.t()
  def escape_markdown_v2(nil), do: ""
  def escape_markdown_v2(text), do: Regex.replace(@markdown_v2_specials, text, "\\\\\\1")

  @doc """
  Escapes text for Telegram HTML parse mode.
  """
  @spec escape_html(String.t() | nil) :: String.t()
  def escape_html(nil), do: ""

  def escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  @doc """
  Formats text for a Telegram parse mode.
  """
  @spec format_text(String.t(), :markdown_v2 | :html | :plain | String.t()) :: %{
          text: String.t(),
          parse_mode: String.t() | nil
        }
  def format_text(text, mode)

  def format_text(text, :markdown_v2),
    do: %{text: escape_markdown_v2(text), parse_mode: "MarkdownV2"}

  def format_text(text, "MarkdownV2"), do: format_text(text, :markdown_v2)
  def format_text(text, :html), do: %{text: escape_html(text), parse_mode: "HTML"}
  def format_text(text, "HTML"), do: format_text(text, :html)
  def format_text(text, _mode), do: %{text: text || "", parse_mode: nil}

  @doc """
  Extracts thread metadata from a Telegram message.
  """
  @spec thread_context(map() | nil) :: map()
  def thread_context(nil), do: %{}

  def thread_context(message) do
    %{}
    |> put_present(:message_id, get_value(message, "message_id"))
    |> put_present(:thread_id, get_value(message, "message_thread_id"))
    |> put_present(:chat_id, get_in_value(message, ["chat", "id"]))
  end

  @doc """
  Extracts reply metadata from a Telegram message.
  """
  @spec reply_context(map() | nil) :: map() | nil
  def reply_context(nil), do: nil

  def reply_context(message) do
    case get_value(message, "reply_to_message") do
      reply when is_map(reply) ->
        %{
          message_id: get_value(reply, "message_id"),
          chat_id: get_in_value(reply, ["chat", "id"]),
          user_id: get_in_value(reply, ["from", "id"]),
          text: message_text(reply)
        }

      _ ->
        nil
    end
  end

  @doc """
  Extracts callback-query metadata from an update.
  """
  @spec callback_query_context(map()) :: map() | nil
  def callback_query_context(update) do
    case get_value(update, "callback_query") do
      callback when is_map(callback) ->
        %{
          id: get_value(callback, "id"),
          data: get_value(callback, "data"),
          from_id: get_in_value(callback, ["from", "id"]),
          message_id: get_in_value(callback, ["message", "message_id"]),
          chat_id: get_in_value(callback, ["message", "chat", "id"])
        }

      _ ->
        nil
    end
  end

  @doc """
  Extracts `/start` deep-link payloads.
  """
  @spec deep_link_payload(String.t() | nil, String.t() | nil) :: map() | nil
  def deep_link_payload(text, bot_username \\ nil) do
    case parse_command(text, bot_username) do
      %{command: "start", raw_args: payload} when payload != "" ->
        %{payload: payload, decoded: url_decode(payload)}

      _ ->
        nil
    end
  end

  defp extract_message(%{"message" => message}) when is_map(message),
    do: {message_type(message), message}

  defp extract_message(%{"edited_message" => message}) when is_map(message),
    do: {:edited_message, message}

  defp extract_message(%{"channel_post" => message}) when is_map(message),
    do: {:channel_post, message}

  defp extract_message(%{"edited_channel_post" => message}) when is_map(message),
    do: {:edited_channel_post, message}

  defp extract_message(%{"callback_query" => %{"message" => message}}) when is_map(message),
    do: {:callback_query, message}

  defp extract_message(%{"inline_query" => _}), do: {:inline_query, nil}
  defp extract_message(_), do: {:unknown, nil}

  defp message_type(%{"text" => _}), do: :text
  defp message_type(%{"photo" => _}), do: :photo
  defp message_type(%{"document" => _}), do: :document
  defp message_type(%{"video" => _}), do: :video
  defp message_type(%{"voice" => _}), do: :voice
  defp message_type(%{"audio" => _}), do: :audio
  defp message_type(%{"sticker" => _}), do: :sticker
  defp message_type(%{"location" => _}), do: :location
  defp message_type(%{"contact" => _}), do: :contact
  defp message_type(%{"poll" => _}), do: :poll
  defp message_type(%{"new_chat_members" => _}), do: :new_chat_members
  defp message_type(%{"left_chat_member" => _}), do: :left_chat_member
  defp message_type(_), do: :message

  defp message_text(nil), do: nil
  defp message_text(message), do: get_value(message, "text") || get_value(message, "caption")

  defp user_id(update, message) do
    get_in_value(message, ["from", "id"]) ||
      get_in_value(update, ["callback_query", "from", "id"]) ||
      get_in_value(update, ["inline_query", "from", "id"])
  end

  defp split_args(""), do: []

  defp split_args(args) do
    Regex.scan(~r/"([^"]*)"|'([^']*)'|(\S+)/u, args, capture: :all_but_first)
    |> Enum.map(fn captures ->
      Enum.find(captures, "", &(&1 not in [nil, ""]))
    end)
  end

  defp addressed?(nil, _bot_username), do: true
  defp addressed?(_bot, nil), do: true
  defp addressed?(bot, bot_username), do: String.downcase(bot) == String.downcase(bot_username)

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  defp get_value(map, key, default \\ nil)
  defp get_value(nil, _key, default), do: default

  defp get_value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, String.to_atom(key), default))

  defp get_in_value(map, keys) do
    Enum.reduce_while(keys, map, fn key, acc ->
      case get_value(acc, key) do
        nil -> {:halt, nil}
        value -> {:cont, value}
      end
    end)
  end

  defp url_decode(value) do
    value
    |> String.replace("+", " ")
    |> URI.decode()
  rescue
    _ -> value
  end
end
