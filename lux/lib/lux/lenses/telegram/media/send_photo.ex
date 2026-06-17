defmodule Lux.Lenses.Telegram.Media.SendPhoto do
  @moduledoc """
  A lens for sending photos.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Telegram Send Photo",
    description: "Sends photos. On success, the sent Message is returned.",
    url: "https://api.telegram.org/bot<token>/sendPhoto",
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
        photo: %{
          type: :string,
          description: "Photo to send. Pass a file_id as String to send a photo that exists on the Telegram servers (recommended), pass an HTTP URL as a String for Telegram to get a photo from the Internet."
        },
        caption: %{
          type: :string,
          description: "Photo caption (may also be used when resending photos by file_id), 0-1024 characters."
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the photo caption.",
          enum: ["MarkdownV2", "HTML", "Markdown"]
        }
      },
      required: ["chat_id", "photo"]
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
