defmodule Lux.Integrations.Telegram.MessageProcessing.ReplyManager do
  @moduledoc """
  Manages Telegram message replies, quote parsing (Telegram Bot API 7.0+),
  reply chain resolution, and smart reply parameter construction.
  """

  @doc """
  Checks if a message is a reply to another message.
  """
  @spec reply?(map()) :: boolean()
  def reply?(message) when is_map(message) do
    msg = normalize_keys(message)
    Map.has_key?(msg, :reply_to_message) and Map.get(msg, :reply_to_message) != nil
  end

  def reply?(_), do: false

  @doc """
  Resolves reply context from a message, including replied message details
  and quote attributes if present.
  """
  @spec resolve_reply(map()) :: {:ok, map()} | {:error, :not_a_reply}
  def resolve_reply(message) when is_map(message) do
    msg = normalize_keys(message)

    case Map.get(msg, :reply_to_message) do
      nil ->
        {:error, :not_a_reply}

      replied when is_map(replied) ->
        replied_norm = normalize_keys(replied)
        quote_data = extract_quote(msg)

        {:ok,
         %{
           has_reply: true,
           replied_message_id: Map.get(replied_norm, :message_id),
           replied_date: Map.get(replied_norm, :date),
           replied_sender: extract_sender(replied_norm),
           replied_text: Map.get(replied_norm, :text) || Map.get(replied_norm, :caption),
           quote: quote_data
         }}
    end
  end

  def resolve_reply(_), do: {:error, :invalid_message}

  @doc """
  Builds modern Telegram Bot API 7.0+ `reply_parameters` map.

  ## Options:
    - `:quote` - Specific string slice to quote
    - `:quote_position` - Integer position where quote starts
    - `:allow_sending_without_reply` - boolean (default true)
  """
  @spec build_reply_parameters(map(), keyword()) :: map()
  def build_reply_parameters(message, opts \\ []) when is_map(message) do
    msg = normalize_keys(message)
    message_id = Map.get(msg, :message_id)

    params = %{
      message_id: message_id,
      allow_sending_without_reply: Keyword.get(opts, :allow_sending_without_reply, true)
    }

    params =
      case Keyword.get(opts, :quote) do
        nil ->
          params

        quote_str when is_binary(quote_str) ->
          p = Map.put(params, :quote, quote_str)

          case Keyword.get(opts, :quote_position) do
            nil -> p
            pos when is_integer(pos) -> Map.put(p, :quote_position, pos)
          end
      end

    case Keyword.get(opts, :chat_id) do
      nil -> params
      c_id -> Map.put(params, :chat_id, c_id)
    end
  end

  @doc """
  Builds conversational context prompt formatted for LLMs, combining
  replied text and incoming message text.
  """
  def format_llm_context(message) when is_map(message) do
    msg = normalize_keys(message)
    incoming_text = Map.get(msg, :text) || Map.get(msg, :caption) || ""

    case resolve_reply(msg) do
      {:ok, reply_info} ->
        quoted =
          cond do
            reply_info.quote && reply_info.quote.text ->
              "> [Quoted]: #{reply_info.quote.text}"

            reply_info.replied_text ->
              author = (reply_info.replied_sender && reply_info.replied_sender.first_name) || "User"
              "> [Replying to #{author}]: #{reply_info.replied_text}"

            true ->
              "> [Replying to previous message]"
          end

        "#{quoted}\n\n#{incoming_text}"

      {:error, _} ->
        incoming_text
    end
  end

  # Extracts Quote object (Telegram Bot API 7.0+)
  defp extract_quote(msg) do
    case Map.get(msg, :quote) do
      q when is_map(q) ->
        q_norm = normalize_keys(q)
        %{
          text: Map.get(q_norm, :text),
          position: Map.get(q_norm, :position),
          is_manual: Map.get(q_norm, :is_manual, false),
          entities: Map.get(q_norm, :entities, [])
        }

      _ ->
        nil
    end
  end

  defp extract_sender(msg) do
    case Map.get(msg, :from) do
      from when is_map(from) ->
        from_norm = normalize_keys(from)
        %{
          id: Map.get(from_norm, :id),
          first_name: Map.get(from_norm, :first_name),
          username: Map.get(from_norm, :username)
        }

      _ ->
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
