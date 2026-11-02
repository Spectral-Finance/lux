defmodule Lux.Prisms.Telegram.GroupManagement.ManagePinnedMessage do
  @moduledoc """
  A prism for pinning, unpinning, or clearing pinned messages in a Telegram group or channel.
  """

  use Lux.Prism,
    name: "Manage Telegram Pinned Message",
    description: "Pins or unpins messages in a chat or channel with silent notification options",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, description: "'pin', 'unpin', or 'unpin_all'"},
        chat_id: %{type: [:string, :integer], description: "Target chat identifier"},
        message_id: %{type: :integer, description: "Message identifier (for 'pin' or specific 'unpin')"},
        disable_notification: %{type: :boolean, description: "Pin silently"}
      },
      required: ["action", "chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        chat_id: %{type: [:string, :integer]},
        message_id: %{type: [:integer, :null]}
      },
      required: ["status", "chat_id"]
    }

  alias Lux.Integrations.Telegram.GroupManagement.ChannelPostManager

  def handler(params, _agent) when is_map(params) do
    action = to_string(Map.get(params, :action) || Map.get(params, "action", "pin"))
    chat_id = Map.get(params, :chat_id) || Map.get(params, "chat_id")
    message_id = Map.get(params, :message_id) || Map.get(params, "message_id")
    disable_notification = Map.get(params, :disable_notification, false)
    plug = Map.get(params, :plug)

    opts = [disable_notification: disable_notification]
    opts = if message_id, do: [{:message_id, message_id} | opts], else: opts
    opts = if plug, do: [{:plug, plug} | opts], else: opts

    case action do
      "pin" when is_integer(message_id) ->
        with {:ok, _} <- ChannelPostManager.pin_message(chat_id, message_id, opts) do
          {:ok, %{status: "pinned", chat_id: chat_id, message_id: message_id}}
        end

      "unpin" ->
        with {:ok, _} <- ChannelPostManager.unpin_message(chat_id, opts) do
          {:ok, %{status: "unpinned", chat_id: chat_id, message_id: message_id}}
        end

      "unpin_all" ->
        with {:ok, _} <- ChannelPostManager.unpin_all_messages(chat_id, opts) do
          {:ok, %{status: "unpinned_all", chat_id: chat_id, message_id: nil}}
        end

      other ->
        {:error, "Unsupported pin action: #{other}"}
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters"}
end
