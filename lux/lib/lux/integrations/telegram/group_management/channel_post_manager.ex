defmodule Lux.Integrations.Telegram.GroupManagement.ChannelPostManager do
  @moduledoc """
  Manages pinning, unpinning, and inspection of pinned messages in Telegram groups and channels.
  """

  alias Lux.Integrations.Telegram.Client

  @doc """
  Pins a message in a group, supergroup, or channel.

  ## Options:
    - `:disable_notification` - Pass true to pin silently without notification.
    - `:plug` - Optional test plug.
  """
  @spec pin_message(integer() | String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def pin_message(chat_id, message_id, opts \\ []) do
    payload =
      %{chat_id: chat_id, message_id: message_id}
      |> maybe_put(:disable_notification, opts[:disable_notification])

    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/pinChatMessage", request_opts)
  end

  @doc """
  Unpins a specific message in a chat. If message_id is omitted or nil, unpins the most recent pinned message.
  """
  @spec unpin_message(integer() | String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def unpin_message(chat_id, opts \\ []) do
    payload =
      %{chat_id: chat_id}
      |> maybe_put(:message_id, opts[:message_id])

    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/unpinChatMessage", request_opts)
  end

  @doc """
  Clears the list of pinned messages in a chat.
  """
  @spec unpin_all_messages(integer() | String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def unpin_all_messages(chat_id, opts \\ []) do
    payload = %{chat_id: chat_id}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/unpinAllChatMessages", request_opts)
  end

  @doc """
  Gets up to date information about the chat including linked chat ID and pinned message.
  """
  @spec get_chat(integer() | String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_chat(chat_id, opts \\ []) do
    payload = %{chat_id: chat_id}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/getChat", request_opts)
  end

  # --- Internal Helpers ---

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp maybe_put_plug(map, nil), do: map
  defp maybe_put_plug(map, plug), do: Map.put(map, :plug, plug)
end
