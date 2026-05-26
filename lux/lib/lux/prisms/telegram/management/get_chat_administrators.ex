defmodule Lux.Prisms.Telegram.Management.GetChatAdministrators do
  @moduledoc """
  A prism for getting a list of administrators in a chat.
  """

  alias Lux.Integrations.Telegram.Client

  use Lux.Prism,
    name: "Get Telegram Chat Administrators",
    description: "Returns an Array of ChatMember objects",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Unique identifier for the target chat"}
      },
      required: ["chat_id"]
    }

  def handler(params, _agent) do
    case Client.request(:get, "/getChatAdministrators", %{json: params}) do
      {:ok, %{"ok" => true, "result" => result}} -> {:ok, result}
      {:ok, response} -> {:error, response}
      {:error, error} -> {:error, error}
    end
  end
end
