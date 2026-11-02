defmodule Lux.Integrations.Telegram.MessageProcessing.ContentAnalyzer do
  @moduledoc """
  Analyzes incoming Telegram messages, classifies message types, extracts rich metadata,
  computes text statistics, and parses message entities and media attributes.
  """

  @media_types [
    :photo,
    :video,
    :audio,
    :voice,
    :video_note,
    :document,
    :sticker,
    :animation,
    :location,
    :venue,
    :contact,
    :poll,
    :dice,
    :game,
    :invoice,
    :successful_payment
  ]

  @service_types [
    :new_chat_members,
    :left_chat_member,
    :new_chat_title,
    :new_chat_photo,
    :delete_chat_photo,
    :group_chat_created,
    :supergroup_chat_created,
    :channel_chat_created,
    :pinned_message,
    :forum_topic_created,
    :forum_topic_edited,
    :forum_topic_closed,
    :forum_topic_reopened
  ]

  @doc """
  Analyzes a raw Telegram message map (supporting string or atom keys)
  and returns a structured analysis map.
  """
  @spec analyze(map()) :: {:ok, map()} | {:error, String.t()}
  def analyze(message) when is_map(message) do
    msg = normalize_keys(message)

    message_type = detect_message_type(msg)
    sender = extract_sender(msg)
    chat = extract_chat(msg)
    text_content = get_text_content(msg)
    text_stats = compute_text_stats(text_content)
    media_info = extract_media_info(msg, message_type)
    entities = extract_entities(msg, text_content)
    flags = extract_flags(msg)

    {:ok,
     %{
       message_id: Map.get(msg, :message_id),
       date: Map.get(msg, :date),
       message_type: message_type,
       sender: sender,
       chat: chat,
       text: text_content,
       text_stats: text_stats,
       media_info: media_info,
       entities: entities,
       flags: flags,
       thread_id: Map.get(msg, :message_thread_id)
     }}
  rescue
    e -> {:error, "Failed to analyze message: #{Exception.message(e)}"}
  end

  def analyze(_), do: {:error, "Message must be a map"}

  @doc """
  Detects the primary type of the Telegram message.
  """
  @spec detect_message_type(map()) :: atom()
  def detect_message_type(msg) do
    cond do
      Map.has_key?(msg, :text) ->
        :text

      match = Enum.find(@media_types, &Map.has_key?(msg, &1)) ->
        match

      match = Enum.find(@service_types, &Map.has_key?(msg, &1)) ->
        match

      true ->
        :unknown
    end
  end

  @doc """
  Extracts the sender information from the message.
  """
  def extract_sender(msg) do
    case Map.get(msg, :from) do
      from when is_map(from) ->
        from_norm = normalize_keys(from)

        %{
          id: Map.get(from_norm, :id),
          is_bot: Map.get(from_norm, :is_bot, false),
          first_name: Map.get(from_norm, :first_name),
          last_name: Map.get(from_norm, :last_name),
          username: Map.get(from_norm, :username),
          language_code: Map.get(from_norm, :language_code)
        }

      _ ->
        nil
    end
  end

  @doc """
  Extracts chat information from the message.
  """
  def extract_chat(msg) do
    case Map.get(msg, :chat) do
      chat when is_map(chat) ->
        chat_norm = normalize_keys(chat)

        %{
          id: Map.get(chat_norm, :id),
          type: Map.get(chat_norm, :type),
          title: Map.get(chat_norm, :title),
          username: Map.get(chat_norm, :username),
          is_forum: Map.get(chat_norm, :is_forum, false)
        }

      _ ->
        nil
    end
  end

  @doc """
  Extracts text or caption content from the message.
  """
  def get_text_content(msg) do
    Map.get(msg, :text) || Map.get(msg, :caption) || ""
  end

  @doc """
  Computes text statistics including character count, word count, line count,
  token approximations, and content markers.
  """
  def compute_text_stats(nil), do: compute_text_stats("")

  def compute_text_stats(text) when is_binary(text) do
    trimmed = String.trim(text)
    char_count = String.length(text)
    words = if trimmed == "", do: [], else: String.split(trimmed, ~r/\s+/)
    word_count = length(words)
    lines = if text == "", do: [], else: String.split(text, "\n")
    line_count = length(lines)

    # Heuristic for token count (approx ~4 chars per token)
    estimated_tokens = max(1, round(char_count / 4.0))

    %{
      char_count: char_count,
      word_count: word_count,
      line_count: line_count,
      estimated_tokens: estimated_tokens,
      has_links: String.contains?(text, ["http://", "https://", "t.me/"]),
      has_mentions: String.contains?(text, "@"),
      has_commands: String.starts_with?(trimmed, "/")
    }
  end

  @doc """
  Extracts media specific information depending on message type.
  """
  def extract_media_info(msg, type) when type in @media_types do
    media_data = Map.get(msg, type)

    case type do
      :photo when is_list(media_data) ->
        # Telegram returns photos as a list of PhotoSize (sorted from smallest to largest)
        best_photo = List.last(media_data) |> normalize_keys()

        %{
          type: :photo,
          file_id: Map.get(best_photo, :file_id),
          file_unique_id: Map.get(best_photo, :file_unique_id),
          file_size: Map.get(best_photo, :file_size),
          width: Map.get(best_photo, :width),
          height: Map.get(best_photo, :height),
          variants_count: length(media_data),
          caption: Map.get(msg, :caption)
        }

      type when type in [:video, :audio, :voice, :video_note, :document, :animation, :sticker] and is_map(media_data) ->
        norm = normalize_keys(media_data)

        %{
          type: type,
          file_id: Map.get(norm, :file_id),
          file_unique_id: Map.get(norm, :file_unique_id),
          file_size: Map.get(norm, :file_size),
          mime_type: Map.get(norm, :mime_type),
          duration: Map.get(norm, :duration),
          width: Map.get(norm, :width),
          height: Map.get(norm, :height),
          file_name: Map.get(norm, :file_name),
          caption: Map.get(msg, :caption)
        }

      :location when is_map(media_data) ->
        norm = normalize_keys(media_data)

        %{
          type: :location,
          latitude: Map.get(norm, :latitude),
          longitude: Map.get(norm, :longitude),
          horizontal_accuracy: Map.get(norm, :horizontal_accuracy)
        }

      :contact when is_map(media_data) ->
        norm = normalize_keys(media_data)

        %{
          type: :contact,
          phone_number: Map.get(norm, :phone_number),
          first_name: Map.get(norm, :first_name),
          last_name: Map.get(norm, :last_name),
          user_id: Map.get(norm, :user_id)
        }

      :poll when is_map(media_data) ->
        norm = normalize_keys(media_data)

        %{
          type: :poll,
          id: Map.get(norm, :id),
          question: Map.get(norm, :question),
          options: Map.get(norm, :options, []),
          total_voter_count: Map.get(norm, :total_voter_count, 0),
          is_closed: Map.get(norm, :is_closed, false)
        }

      _ ->
        %{type: type, raw_data: media_data}
    end
  end

  def extract_media_info(_msg, _type), do: nil

  @doc """
  Parses Telegram entities and extracts their text slices.
  """
  def extract_entities(msg, text) do
    raw_entities = Map.get(msg, :entities) || Map.get(msg, :caption_entities) || []

    Enum.map(raw_entities, fn entity ->
      norm = normalize_keys(entity)
      offset = Map.get(norm, :offset, 0)
      length = Map.get(norm, :length, 0)

      # Telegram offsets and lengths are in UTF-16 code units.
      # For standard ASCII/Unicode strings in Elixir:
      extracted_value = slice_utf16_or_utf8(text, offset, length)

      %{
        type: Map.get(norm, :type),
        offset: offset,
        length: length,
        value: extracted_value,
        url: Map.get(norm, :url),
        user: Map.get(norm, :user),
        language: Map.get(norm, :language),
        custom_emoji_id: Map.get(norm, :custom_emoji_id)
      }
    end)
  end

  @doc """
  Extracts boolean flags for quick routing logic.
  """
  def extract_flags(msg) do
    %{
      is_forwarded: Map.has_key?(msg, :forward_date) or Map.has_key?(msg, :forward_from) or Map.has_key?(msg, :forward_from_chat),
      is_reply: Map.has_key?(msg, :reply_to_message),
      is_topic_message: Map.get(msg, :is_topic_message, false) or Map.has_key?(msg, :message_thread_id),
      is_edited: Map.has_key?(msg, :edit_date),
      has_media: Enum.any?(@media_types, &Map.has_key?(msg, &1)),
      has_protected_content: Map.get(msg, :has_protected_content, false)
    }
  end

  # Helper to normalize maps with string or atom keys to atom keys
  defp normalize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), normalize_value(v)}
      {k, v} when is_atom(k) -> {k, normalize_value(v)}
      {k, v} -> {k, v}
    end)
  end

  defp normalize_keys(other), do: other

  defp normalize_value(list) when is_list(list) do
    Enum.map(list, &normalize_value/1)
  end

  defp normalize_value(map) when is_map(map) do
    normalize_keys(map)
  end

  defp normalize_value(other), do: other

  defp slice_utf16_or_utf8(text, offset, length) when is_binary(text) and is_integer(offset) and is_integer(length) do
    String.slice(text, offset, length)
  rescue
    _ -> ""
  end

  defp slice_utf16_or_utf8(_, _, _), do: ""
end
