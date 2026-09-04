defmodule Lux.Signals.TelegramUpdate do
  @moduledoc """
  Represents a Telegram Update signal in the Lux framework.
  Provides constructor `new/1` and helper functions for extracting update data.
  """

  use Lux.Signal, schema_id: Lux.Schemas.TelegramUpdateSchema

  alias Lux.Schemas.TelegramUpdateSchema
  alias Lux.Telegram.Types

  @type t :: Lux.Signal.t()

  @doc """
  Creates a new Telegram Update signal.
  Supports:
  - `%Lux.Telegram.Types.Update{}`
  - Raw update maps with atom or string keys (`%{update_id: _}` or `%{"update_id" => _}`)
  - Structured signal maps with `:payload` or `"payload"`
  """
  @spec new(term()) :: {:ok, Lux.Signal.t()} | {:error, term()}
  def new(%Types.Update{} = update) do
    payload = Types.to_map(update)
    build_and_validate(%{payload: payload})
  end

  def new(%{payload: payload} = attrs) when is_map(attrs) do
    build_and_validate(attrs, payload)
  end

  def new(%{"payload" => payload} = attrs) when is_map(attrs) do
    build_and_validate(attrs, payload)
  end

  def new(raw_update) when is_map(raw_update) do
    build_and_validate(%{payload: raw_update}, raw_update)
  end

  def new(_invalid) do
    {:error, :invalid_update}
  end

  defp build_and_validate(attrs, payload \\ nil) do
    payload = payload || Map.get(attrs, :payload) || Map.get(attrs, "payload") || %{}

    payload_map =
      case payload do
        %Types.Update{} = u -> Types.to_map(u)
        p when is_map(p) -> p
        _ -> payload
      end

    signal = %Lux.Signal{
      id: Map.get(attrs, :id) || Map.get(attrs, "id") || Lux.UUID.generate(),
      payload: payload_map,
      sender: Map.get(attrs, :sender) || Map.get(attrs, "sender"),
      recipient: Map.get(attrs, :recipient) || Map.get(attrs, "recipient"),
      timestamp: Map.get(attrs, :timestamp) || Map.get(attrs, "timestamp") || DateTime.utc_now(),
      topic: Map.get(attrs, :topic) || Map.get(attrs, "topic"),
      metadata: Map.get(attrs, :metadata) || Map.get(attrs, "metadata") || %{},
      schema_id: TelegramUpdateSchema
    }

    TelegramUpdateSchema.validate(signal)
  end

  @doc """
  Converts a TelegramUpdate signal, update map, or update struct to a `%Lux.Telegram.Types.Update{}` struct.
  """
  @spec to_struct(Lux.Signal.t() | Types.Update.t() | map() | nil) :: Types.Update.t() | nil
  def to_struct(nil), do: nil
  def to_struct(%Types.Update{} = update), do: update
  def to_struct(%Lux.Signal{payload: payload}), do: to_struct(payload)
  def to_struct(map) when is_map(map), do: Types.Update.from_map(map)
  def to_struct(_), do: nil

  @doc """
  Recursively converts all string keys to atom keys in the signal payload or given map.
  """
  @spec to_atom_keys(term()) :: term()
  def to_atom_keys(%Lux.Signal{payload: payload}), do: to_atom_keys(payload)

  def to_atom_keys(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> to_atom_keys()
  end

  def to_atom_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        safe_key =
          try do
            String.to_existing_atom(k)
          rescue
            ArgumentError -> k
          end

        {safe_key, to_atom_keys(v)}

      {k, v} when is_atom(k) ->
        {k, to_atom_keys(v)}

      {k, v} ->
        {k, to_atom_keys(v)}
    end)
  end

  def to_atom_keys(list) when is_list(list) do
    Enum.map(list, &to_atom_keys/1)
  end

  def to_atom_keys(other), do: other

  @doc """
  Extracts the `update_id` from a signal, update struct, or map.
  """
  @spec update_id(Lux.Signal.t() | Types.Update.t() | map() | nil) :: integer() | nil
  def update_id(target) do
    target
    |> extract_payload()
    |> get_field(:update_id)
  end

  @doc """
  Extracts the `message` from a signal, update struct, or map.
  """
  @spec message(Lux.Signal.t() | Types.Update.t() | map() | nil) :: term()
  def message(target) do
    target
    |> extract_payload()
    |> get_field(:message)
  end

  @doc """
  Extracts the `callback_query` from a signal, update struct, or map.
  """
  @spec callback_query(Lux.Signal.t() | Types.Update.t() | map() | nil) :: term()
  def callback_query(target) do
    target
    |> extract_payload()
    |> get_field(:callback_query)
  end

  @doc """
  Extracts the `chat_id` from a signal, update struct, or map.
  Inspects message, edited_message, channel_post, edited_channel_post,
  callback_query, my_chat_member, chat_member, and chat_join_request.
  """
  @spec chat_id(Lux.Signal.t() | Types.Update.t() | map() | nil) :: integer() | String.t() | nil
  def chat_id(target) do
    payload = extract_payload(target)

    find_chat_id(payload, [
      [:message, :chat, :id],
      [:edited_message, :chat, :id],
      [:channel_post, :chat, :id],
      [:edited_channel_post, :chat, :id],
      [:callback_query, :message, :chat, :id],
      [:callback_query, :chat_instance],
      [:my_chat_member, :chat, :id],
      [:chat_member, :chat, :id],
      [:chat_join_request, :chat, :id]
    ])
  end

  @doc """
  Extracts text or caption from a signal, update struct, or map.
  Checks message.text, edited_message.text, channel_post.text,
  edited_channel_post.text, message.caption, callback_query.data, etc.
  """
  @spec text(Lux.Signal.t() | Types.Update.t() | map() | nil) :: String.t() | nil
  def text(target) do
    payload = extract_payload(target)

    get_nested(payload, [:message, :text]) ||
      get_nested(payload, [:edited_message, :text]) ||
      get_nested(payload, [:channel_post, :text]) ||
      get_nested(payload, [:edited_channel_post, :text]) ||
      get_nested(payload, [:message, :caption]) ||
      get_nested(payload, [:callback_query, :data]) ||
      get_nested(payload, [:callback_query, :message, :text])
  end

  defp extract_payload(%Lux.Signal{payload: payload}), do: payload
  defp extract_payload(other), do: other

  defp find_chat_id(_payload, []), do: nil

  defp find_chat_id(payload, [path | rest]) do
    case get_nested(payload, path) do
      nil -> find_chat_id(payload, rest)
      val -> val
    end
  end

  defp get_nested(nil, _), do: nil
  defp get_nested(target, []), do: target

  defp get_nested(target, [key | rest]) do
    target
    |> get_field(key)
    |> get_nested(rest)
  end

  defp get_field(nil, _), do: nil
  defp get_field(%_{} = struct, key), do: Map.get(struct, key)

  defp get_field(map, key) when is_map(map) and is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, val} -> val
      :error -> Map.get(map, Atom.to_string(key))
    end
  end

  defp get_field(_, _), do: nil
end
