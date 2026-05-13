defmodule Lux.Integrations.Telegram.MessageProcessor do
  @moduledoc """
  Utilities for processing Telegram updates and messages.
  """

  @markdown_v2_escape ~r/([_*\[\]()~`>#+\-=|{}.!\\])/

  @doc """
  Classifies a Telegram update into its primary route.
  """
  @spec classify_update(map()) :: atom()
  def classify_update(%{"message" => %{"text" => text}}) when is_binary(text), do: :text_message
  def classify_update(%{"message" => %{"photo" => _photo}}), do: :photo_message
  def classify_update(%{"message" => %{"document" => _document}}), do: :document_message
  def classify_update(%{"message" => %{"voice" => _voice}}), do: :voice_message
  def classify_update(%{"message" => _message}), do: :message
  def classify_update(%{"edited_message" => _message}), do: :edited_message
  def classify_update(%{"callback_query" => _query}), do: :callback_query
  def classify_update(%{"inline_query" => _query}), do: :inline_query
  def classify_update(_update), do: :unknown

  @doc """
  Parses a bot command and positional arguments from message text.
  """
  @spec parse_command(String.t(), keyword() | map()) :: {:ok, map()} | :ignore
  def parse_command(text, opts \\ %{}) when is_binary(text) do
    bot_username = opts[:bot_username]

    case Regex.named_captures(~r/^\/(?<command>[A-Za-z0-9_]+)(?:@(?<bot>[A-Za-z0-9_]+))?(?:\s+(?<args>.*))?$/u, text) do
      %{"args" => args, "bot" => bot, "command" => command} ->
        if bot == "" or is_nil(bot_username) or String.downcase(bot) == String.downcase(bot_username) do
          {:ok,
           %{
             command: command,
             bot: empty_to_nil(bot),
             args: split_args(args),
             raw_args: empty_to_nil(args)
           }}
        else
          :ignore
        end

      _ ->
        :ignore
    end
  end

  @doc """
  Extracts deep-link payloads from `/start <payload>` commands.
  """
  @spec deep_link_payload(String.t(), keyword() | map()) :: {:ok, String.t()} | :ignore
  def deep_link_payload(text, opts \\ %{}) do
    case parse_command(text, opts) do
      {:ok, %{command: "start", raw_args: payload}} when is_binary(payload) and payload != "" ->
        {:ok, payload}

      _ ->
        :ignore
    end
  end

  @doc """
  Decodes callback query data into action and payload parts.
  """
  @spec decode_callback_data(String.t()) :: map()
  def decode_callback_data(data) when is_binary(data) do
    case String.split(data, ":", parts: 2) do
      [action, payload] -> %{action: action, payload: payload}
      [action] -> %{action: action, payload: nil}
    end
  end

  @doc """
  Extracts thread and reply context from a message.
  """
  @spec thread_context(map()) :: map()
  def thread_context(message) do
    %{
      chat_id: get_in(message, ["chat", "id"]),
      message_id: Map.get(message, "message_id"),
      message_thread_id: Map.get(message, "message_thread_id"),
      reply_to_message_id: get_in(message, ["reply_to_message", "message_id"]),
      reply_to_user_id: get_in(message, ["reply_to_message", "from", "id"])
    }
  end

  @doc """
  Escapes text for Telegram MarkdownV2 parse mode.
  """
  @spec escape_markdown_v2(String.t()) :: String.t()
  def escape_markdown_v2(text) when is_binary(text) do
    Regex.replace(@markdown_v2_escape, text, "\\\\\\1")
  end

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

  defp split_args(nil), do: []
  defp split_args(""), do: []

  defp split_args(args) do
    args
    |> String.split(~r/\s+/, trim: true)
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value
end
