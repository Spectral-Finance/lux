defmodule Lux.Integrations.Telegram.MessageProcessing.ThreadManager do
  @moduledoc """
  Manages Telegram supergroup forum topics and message threading.
  Extracts thread context, generates thread reply parameters, and handles forum topic events.
  """

  @doc """
  Extracts thread information from a Telegram message map.
  Returns `%{is_thread: boolean(), thread_id: integer() | nil, is_general_topic: boolean()}`.
  """
  @spec extract_thread_info(map()) :: map()
  def extract_thread_info(message) when is_map(message) do
    msg = normalize_keys(message)
    thread_id = Map.get(msg, :message_thread_id)
    is_topic = Map.get(msg, :is_topic_message, false) || (thread_id != nil)

    %{
      is_thread: is_topic,
      thread_id: thread_id,
      # In Telegram, General topic in forum supergroups has thread_id == 1 or message_thread_id == 1
      is_general_topic: thread_id == 1,
      forum_event: extract_forum_event(msg)
    }
  end

  def extract_thread_info(_), do: %{is_thread: false, thread_id: nil, is_general_topic: false, forum_event: nil}

  @doc """
  Determines if a message was posted inside a forum topic.
  """
  @spec is_topic_message?(map()) :: boolean()
  def is_topic_message?(message) when is_map(message) do
    msg = normalize_keys(message)
    Map.get(msg, :is_topic_message, false) or Map.has_key?(msg, :message_thread_id)
  end

  def is_topic_message?(_), do: false

  @doc """
  Constructs send/reply options ensuring the response is sent back into the same thread/topic.
  """
  @spec build_thread_reply_params(map(), keyword()) :: map()
  def build_thread_reply_params(message, opts \\ []) do
    thread_info = extract_thread_info(message)
    msg = normalize_keys(message)
    chat_id = get_in(msg, [:chat, :id]) || Map.get(msg, :chat_id)
    message_id = Map.get(msg, :message_id)

    base = %{chat_id: chat_id}

    params =
      if thread_info.thread_id do
        Map.put(base, :message_thread_id, thread_info.thread_id)
      else
        base
      end

    if Keyword.get(opts, :quote_reply, false) and message_id do
      Map.put(params, :reply_parameters, %{
        message_id: message_id,
        allow_sending_without_reply: true
      })
    else
      params
    end
  end

  @doc """
  Detects and extracts any forum topic service events:
  created, edited, closed, reopened, or hidden.
  """
  @spec extract_forum_event(map()) :: map() | nil
  def extract_forum_event(msg) do
    cond do
      created = Map.get(msg, :forum_topic_created) ->
        created_norm = normalize_keys(created)
        %{
          event: :created,
          name: Map.get(created_norm, :name),
          icon_color: Map.get(created_norm, :icon_color),
          icon_custom_emoji_id: Map.get(created_norm, :icon_custom_emoji_id)
        }

      edited = Map.get(msg, :forum_topic_edited) ->
        edited_norm = normalize_keys(edited)
        %{
          event: :edited,
          name: Map.get(edited_norm, :name),
          icon_custom_emoji_id: Map.get(edited_norm, :icon_custom_emoji_id)
        }

      Map.has_key?(msg, :forum_topic_closed) ->
        %{event: :closed}

      Map.has_key?(msg, :forum_topic_reopened) ->
        %{event: :reopened}

      Map.has_key?(msg, :general_forum_topic_hidden) ->
        %{event: :general_hidden}

      Map.has_key?(msg, :general_forum_topic_unhidden) ->
        %{event: :general_unhidden}

      true ->
        nil
    end
  end

  defp normalize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), normalize_value(v)}
      {k, v} -> {k, normalize_value(v)}
    end)
  end

  defp normalize_keys(other), do: other

  defp normalize_value(map) when is_map(map), do: normalize_keys(map)
  defp normalize_value(other), do: other
end
