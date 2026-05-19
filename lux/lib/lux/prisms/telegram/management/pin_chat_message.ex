defmodule Lux.Prisms.Telegram.Management.PinChatMessage do
  @moduledoc """
  A prism for pinning a message in a group, a supergroup, or a channel.
  """

  alias Lux.Integrations.Telegram.Client

  use Lux.Prism,
    name: "Pin Telegram Message",
    description: "Pins a message in a chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Unique identifier for the target chat"},
        message_id: %{type: :integer, description: "Identifier of a message to pin"},
        disable_notification: %{type: :boolean, description: "Pass True if it is not necessary to send a notification to all chat members about the new pinned message"}
      },
      required: ["chat_id", "message_id"]
    }

  def handler(params, _agent) do
    case Client.request(:post, "/pinChatMessage", %{json: params}) do
      {:ok, %{"ok" => true, "result" => true}} -> {:ok, %{success: true}}
      {:ok, response} -> {:error, response}
      {:error, error} -> {:error, error}
    end
  end
end
