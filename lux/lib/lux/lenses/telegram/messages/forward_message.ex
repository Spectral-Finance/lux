defmodule Lux.Lenses.Telegram.Messages.ForwardMessage do
  @moduledoc """
  A lens for forwarding messages of any kind via Telegram Bot API.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Forward Telegram Message",
    description: "Forwards messages of any kind between chats",
    url: "https://api.telegram.org/bot/forwardMessage",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Target chat unique identifier"
        },
        from_chat_id: %{
          type: :string,
          description: "Chat where the original message was sent"
        },
        message_id: %{
          type: :integer,
          description: "Message identifier in the chat specified in from_chat_id"
        }
      },
      required: ["chat_id", "from_chat_id", "message_id"]
    }

  @impl true
  def before_focus(params) do
    {:ok,
     %{
       "chat_id" => to_string(params.chat_id),
       "from_chat_id" => to_string(params.from_chat_id),
       "message_id" => params.message_id
     }}
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok,
     %{
       message_id: result["message_id"],
       chat_id: get_in(result, ["chat", "id"]),
       forward_date: result["forward_date"]
     }}
  end

  def after_focus(other), do: {:ok, other}
end
