defmodule Lux.Prisms.Discord.MessageManagement do
  @moduledoc """
  Handles all message-related operations within Discord.
  """
  use Lux.Prism

  @description "Manages Discord messages including creation, editing, deletion, and history."

  def run(%{action: :send, channel_id: channel_id, content: content} = params) do
    # Implementation assumes a Discord client library like Nostrum or raw HTTP
    with {:ok, message} <- DiscordClient.create_message(channel_id, content) do
      {:ok, Lux.Lenses.Discord.Message.view(message)}
    else
      {:error, reason} -> {:error, "Failed to send message: #{inspect(reason)}"}
    end
  end

  def run(%{action: :edit, channel_id: channel_id, message_id: message_id, content: content}) do
    case DiscordClient.edit_message(channel_id, message_id, content) do
      {:ok, message} -> {:ok, Lux.Lenses.Discord.Message.view(message)}
      error -> error
    end
  end

  def run(%{action: :delete, channel_id: channel_id, message_id: message_id}) do
    DiscordClient.delete_message(channel_id, message_id)
  end

  def run(%{action: :bulk_delete, channel_id: channel_id, message_ids: ids}) do
    # Discord allows up to 100 messages at once
    ids
    |> Enum.chunk_every(100)
    |> Enum.each(fn chunk -> DiscordClient.bulk_delete_messages(channel_id, chunk) end)
    {:ok, %{deleted_count: length(ids)}}
  end

  def run(%{action: :get_history, channel_id: channel_id, limit: limit}) do
    case DiscordClient.get_channel_messages(channel_id, limit: limit) do
      {:ok, messages} -> {:ok, Enum.map(messages, &Lux.Lenses.Discord.Message.view/1)}
      error -> error
    end
  end
end
