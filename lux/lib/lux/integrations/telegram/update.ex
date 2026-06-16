defmodule Lux.Integrations.Telegram.Update do
  @moduledoc """
  Represents and parses updates received from the Telegram Bot API.

  Provides a unified parser/normalizer that categorizes incoming updates
  and extracts critical properties (id, type, chat_id, user_id, text) while
  preserving the raw payload and full nested structure.
  """

  @type update_type ::
          :message
          | :edited_message
          | :channel_post
          | :edited_channel_post
          | :callback_query
          | :inline_query
          | :chosen_inline_result
          | :shipping_query
          | :pre_checkout_query
          | :poll
          | :poll_answer
          | :my_chat_member
          | :chat_member
          | :chat_join_request
          | :unknown

  @type t :: %__MODULE__{
          id: integer() | nil,
          type: update_type(),
          payload: map() | nil,
          chat_id: integer() | String.t() | nil,
          user_id: integer() | nil,
          text: String.t() | nil,
          raw: map()
        }

  defstruct [:id, :type, :payload, :chat_id, :user_id, :text, :raw]

  @doc """
  Parses a raw Telegram update map and normalizes it into an `%Update{}` struct.

  Supports both string-keyed and atom-keyed maps. Safely handles missing fields
  without throwing exceptions.

  ## Examples

      # Parsing a text message update
      iex> raw_update = %{
      ...>   "update_id" => 10000,
      ...>   "message" => %{
      ...>     "message_id" => 1,
      ...>     "chat" => %{"id" => 123456},
      ...>     "from" => %{"id" => 98765},
      ...>     "text" => "Hello World"
      ...>   }
      ...> }
      iex> Update.parse(raw_update)
      %Update{id: 10000, type: :message, chat_id: 123456, user_id: 98765, text: "Hello World", ...}
  """
  @spec parse(map()) :: t()
  def parse(update) when is_map(update) do
    id = get_val(update, :update_id)

    {type, payload} = detect_type_and_payload(update)

    {chat_id, user_id, text} = extract_properties(type, payload)

    %__MODULE__{
      id: id,
      type: type,
      payload: payload,
      chat_id: chat_id,
      user_id: user_id,
      text: text,
      raw: update
    }
  end

  defp detect_type_and_payload(update) do
    cond do
      payload = get_val(update, :message) -> {:message, payload}
      payload = get_val(update, :edited_message) -> {:edited_message, payload}
      payload = get_val(update, :channel_post) -> {:channel_post, payload}
      payload = get_val(update, :edited_channel_post) -> {:edited_channel_post, payload}
      payload = get_val(update, :callback_query) -> {:callback_query, payload}
      payload = get_val(update, :inline_query) -> {:inline_query, payload}
      payload = get_val(update, :chosen_inline_result) -> {:chosen_inline_result, payload}
      payload = get_val(update, :shipping_query) -> {:shipping_query, payload}
      payload = get_val(update, :pre_checkout_query) -> {:pre_checkout_query, payload}
      payload = get_val(update, :poll) -> {:poll, payload}
      payload = get_val(update, :poll_answer) -> {:poll_answer, payload}
      payload = get_val(update, :my_chat_member) -> {:my_chat_member, payload}
      payload = get_val(update, :chat_member) -> {:chat_member, payload}
      payload = get_val(update, :chat_join_request) -> {:chat_join_request, payload}
      true -> {:unknown, nil}
    end
  end

  defp extract_properties(:message, p), do: {extract_chat_id(p), extract_from_id(p), extract_text_or_caption(p)}
  defp extract_properties(:edited_message, p), do: {extract_chat_id(p), extract_from_id(p), extract_text_or_caption(p)}
  defp extract_properties(:channel_post, p), do: {extract_chat_id(p), extract_from_id(p), extract_text_or_caption(p)}
  defp extract_properties(:edited_channel_post, p), do: {extract_chat_id(p), extract_from_id(p), extract_text_or_caption(p)}

  defp extract_properties(:callback_query, p) do
    msg = get_val(p, :message)
    chat_id = if msg, do: extract_chat_id(msg), else: nil
    {chat_id, extract_from_id(p), get_val(p, :data)}
  end

  defp extract_properties(:inline_query, p), do: {nil, extract_from_id(p), get_val(p, :query)}
  defp extract_properties(:chosen_inline_result, p), do: {nil, extract_from_id(p), get_val(p, :query)}
  defp extract_properties(:shipping_query, p), do: {nil, extract_from_id(p), nil}
  defp extract_properties(:pre_checkout_query, p), do: {nil, extract_from_id(p), nil}
  defp extract_properties(:poll, p), do: {nil, nil, get_val(p, :question)}

  defp extract_properties(:poll_answer, p) do
    user = get_val(p, :user)
    user_id = if user, do: get_val(user, :id), else: nil
    {nil, user_id, nil}
  end

  defp extract_properties(:my_chat_member, p), do: {extract_chat_id(p), extract_from_id(p), nil}
  defp extract_properties(:chat_member, p), do: {extract_chat_id(p), extract_from_id(p), nil}
  defp extract_properties(:chat_join_request, p), do: {extract_chat_id(p), extract_from_id(p), nil}
  defp extract_properties(:unknown, _), do: {nil, nil, nil}

  # --- Helper functions ---

  defp get_val(map, key) when is_map(map) do
    Map.get(map, to_string(key)) || Map.get(map, key)
  end
  defp get_val(_, _), do: nil

  defp extract_chat_id(p) do
    chat = get_val(p, :chat)
    if chat, do: get_val(chat, :id), else: nil
  end

  defp extract_from_id(p) do
    from = get_val(p, :from)
    if from, do: get_val(from, :id), else: nil
  end

  defp extract_text_or_caption(p) do
    get_val(p, :text) || get_val(p, :caption)
  end
end
