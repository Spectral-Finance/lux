defmodule Lux.Lenses.Telegram.Media.SendPhoto do
  @moduledoc \"\"\"
  A lens for sending photos via Telegram Bot API.
  Currently supports sending photos by URL or file_id.
  \"\"\"

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Photo",
    description: "Sends a photo to a chat.",
    url: "https://api.telegram.org/bot/sendPhoto",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Unique identifier for the target chat"
        },
        photo: %{
          type: :string,
          description: "Photo to send. Pass a file_id as String to send a photo that exists on the Telegram servers, or pass an HTTP URL as a String for Telegram to get a photo from the Internet"
        },
        caption: %{
          type: :string,
          description: "Photo caption, 0-1024 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities"
        }
      },
      required: ["chat_id", "photo"]
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(%{"ok" => false, "description" => description} = error) do
    {:error, error}
  end

  def after_focus(error) do
    {:error, error}
  end
end
