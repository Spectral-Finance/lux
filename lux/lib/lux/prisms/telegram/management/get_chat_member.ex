defmodule Lux.Prisms.Telegram.Management.GetChatMember do
  @moduledoc """
  A prism for getting information about a member of a chat.
  """

  alias Lux.Integrations.Telegram.Client

  use Lux.Prism,
    name: "Get Telegram Chat Member",
    description: "Returns a ChatMember object",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Unique identifier for the target chat"},
        user_id: %{type: :integer, description: "Unique identifier of the target user"}
      },
      required: ["chat_id", "user_id"]
    }

  def handler(params, _agent) do
    case Client.request(:get, "/getChatMember", %{json: params}) do
      {:ok, %{"ok" => true, "result" => result}} -> {:ok, result}
      {:ok, response} -> {:error, response}
      {:error, error} -> {:error, error}
    end
  end
end
