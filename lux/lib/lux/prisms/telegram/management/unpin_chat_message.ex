defmodule Lux.Prisms.Telegram.Management.UnpinChatMessage do
  @moduledoc """
  A prism for removing a message from the list of pinned messages in a chat.
  """

  alias Lux.Integrations.Telegram.Client

  use Lux.Prism,
    name: "Unpin Telegram Message",
    description: "Unpins a message in a chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Unique identifier for the target chat"},
        message_id: %{type: :integer, description: "Identifier of a message to unpin. If not specified, the most recent pinned message will be unpinned."}
      },
      required: ["chat_id"]
    }

  def handler(params, _agent) do
    case Client.request(:post, "/unpinChatMessage", %{json: params}) do
      {:ok, %{"ok" => true, "result" => true}} -> {:ok, %{success: true}}
      {:ok, response} -> {:error, response}
      {:error, error} -> {:error, error}
    end
  end
end
