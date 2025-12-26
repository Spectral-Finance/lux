defmodule Lux.Lenses.Telegram.SendPhoto do
  @moduledoc """
  Lens for sending photos via the Telegram Bot API.

  ## Examples

      Lux.Lenses.Telegram.SendPhoto.focus(%{chat_id: "123456", photo: "https://example.com/image.png", caption: "Cool image"})
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Photo",
    description: "Sends a photo to a chat or channel",
    url: "https://api.telegram.org/bot:token/sendPhoto",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Unique identifier for the target chat or username of the target channel"
        },
        photo: %{type: :string, description: "Photo to send. Pass a file_id as string or an HTTP URL"},
        caption: %{type: :string, description: "Photo caption"}
      },
      required: ["chat_id", "photo"]
    }

  def before_focus(params) do
    Map.put(params, :token, Telegram.token())
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok,
     %{
       message_id: result["message_id"],
       photo: result["photo"],
       caption: result["caption"]
     }}
  end

  def after_focus(%{"ok" => false, "description" => description}), do: {:error, description}
  def after_focus(other), do: {:error, other}
end
