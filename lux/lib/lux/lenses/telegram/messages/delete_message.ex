defmodule Lux.Lenses.Telegram.Messages.DeleteMessage do
  @moduledoc """
  A lens for deleting a message.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Telegram Delete Message",
    description: "Deletes a message, including service messages. Returns True on success.",
    url: "https://api.telegram.org/bot<token>/deleteMessage",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:integer, :string],
          description: "Unique identifier for the target chat or username of the target channel."
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message to delete."
        }
      },
      required: ["chat_id", "message_id"]
    }

  @doc """
  Transforms the Telegram API response.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end
  
  def after_focus(other), do: {:error, other}
end
