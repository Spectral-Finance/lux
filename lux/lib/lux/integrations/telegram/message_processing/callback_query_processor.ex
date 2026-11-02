defmodule Lux.Integrations.Telegram.MessageProcessing.CallbackQueryProcessor do
  @moduledoc """
  Processes Telegram callback queries originating from inline keyboard button presses.
  Provides structured callback data encoding/decoding within Telegram's 64-byte limit,
  query routing, and response payload building.
  """

  @max_callback_data_bytes 64
  @default_delimiter ":"

  @doc """
  Parses a raw Telegram callback_query object.
  """
  @spec parse(map()) :: {:ok, map()} | {:error, term()}
  def parse(callback_query) when is_map(callback_query) do
    q = normalize_keys(callback_query)

    query_id = Map.get(q, :id)
    raw_data = Map.get(q, :data) || ""
    from = Map.get(q, :from)
    message = Map.get(q, :message)
    inline_message_id = Map.get(q, :inline_message_id)

    decoded = decode_data(raw_data)

    {:ok,
     %{
       id: query_id,
       raw_data: raw_data,
       action: decoded.action,
       args: decoded.args,
       user: extract_user(from),
       chat_id: extract_chat_id(message),
       message_id: extract_message_id(message),
       inline_message_id: inline_message_id,
       chat_instance: Map.get(q, :chat_instance)
     }}
  rescue
    e -> {:error, "Failed to parse callback query: #{Exception.message(e)}"}
  end

  def parse(_), do: {:error, :invalid_callback_query}

  @doc """
  Encodes an action and arguments into a delimited string <= 64 bytes.
  """
  @spec encode_data(String.t() | atom(), list(term()), String.t()) :: {:ok, String.t()} | {:error, term()}
  def encode_data(action, args \\ [], delimiter \\ @default_delimiter) do
    parts = [to_string(action) | Enum.map(args, &to_string/1)]
    encoded = Enum.join(parts, delimiter)

    if byte_size(encoded) > @max_callback_data_bytes do
      {:error, {:callback_data_too_large, byte_size(encoded)}}
    else
      {:ok, encoded}
    end
  end

  @doc """
  Decodes a callback data string into action and arguments.
  Supports both `:` and `/` delimiters.
  """
  @spec decode_data(String.t()) :: %{action: String.t(), args: list(String.t()), raw: String.t()}
  def decode_data(nil), do: %{action: "", args: [], raw: ""}
  def decode_data(""), do: %{action: "", args: [], raw: ""}

  def decode_data(data) when is_binary(data) do
    delimiter = if String.contains?(data, ":"), do: ":", else: "/"

    case String.split(data, delimiter) do
      [action] ->
        %{action: action, args: [], raw: data}

      [action | args] ->
        %{action: action, args: args, raw: data}
    end
  end

  @doc """
  Constructs response map for answering a callback query via POST /answerCallbackQuery.
  """
  @spec build_answer(String.t(), keyword()) :: map()
  def build_answer(query_id, opts \\ []) do
    base = %{callback_query_id: query_id}

    params =
      case Keyword.get(opts, :text) do
        nil -> base
        text -> Map.put(base, :text, text)
      end

    params =
      case Keyword.get(opts, :show_alert) do
        nil -> params
        alert -> Map.put(params, :show_alert, alert)
      end

    case Keyword.get(opts, :url) do
      nil -> params
      url -> Map.put(params, :url, url)
    end
  end

  # --- Internal Helpers ---

  defp extract_user(from) when is_map(from) do
    from_norm = normalize_keys(from)
    %{
      id: Map.get(from_norm, :id),
      is_bot: Map.get(from_norm, :is_bot, false),
      first_name: Map.get(from_norm, :first_name),
      username: Map.get(from_norm, :username)
    }
  end

  defp extract_user(_), do: nil

  defp extract_chat_id(message) when is_map(message) do
    msg_norm = normalize_keys(message)
    get_in(msg_norm, [:chat, :id])
  end

  defp extract_chat_id(_), do: nil

  defp extract_message_id(message) when is_map(message) do
    msg_norm = normalize_keys(message)
    Map.get(msg_norm, :message_id)
  end

  defp extract_message_id(_), do: nil

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
