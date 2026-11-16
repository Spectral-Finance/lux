defmodule Lux.Lenses.Telegram.Media.SendPhoto do
  @moduledoc """
  A lens for sending photos to Telegram chats via the Telegram Bot API.

  Supports:
  - Photo URLs or existing Telegram file_ids
  - Optional captions with formatting (MarkdownV2, HTML, Markdown)
  - Inline keyboards (reply_markup)
  - Silent delivery (disable_notification)

  ## Examples

      iex> SendPhoto.focus(%{
      ...>   chat_id: "123456789",
      ...>   photo: "https://example.com/chart.png",
      ...>   caption: "Daily Alpha Report",
      ...>   parse_mode: "HTML"
      ...> })
      {:ok, %{
        message_id: 101,
        chat_id: 123456789,
        caption: "Daily Alpha Report",
        photo_id: "AgACAgIAAxkDA..."
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Send Telegram Photo",
    description: "Sends a photo by URL or file_id with optional caption to a Telegram chat",
    url: "https://api.telegram.org/bot/sendPhoto",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Target chat ID or channel username (e.g. '@channelusername')"
        },
        photo: %{
          type: :string,
          description: "Photo to send. Pass an HTTP URL or a Telegram file_id"
        },
        caption: %{
          type: :string,
          description: "Photo caption (0-1024 characters)"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the photo caption",
          enum: ["MarkdownV2", "HTML", "Markdown"]
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently"
        },
        reply_to_message_id: %{
          type: :integer,
          description: "If the message is a reply, ID of the original message"
        },
        reply_markup: %{
          type: :object,
          description: "Inline keyboard or custom reply markup"
        }
      },
      required: ["chat_id", "photo"]
    }

  @doc """
  Transforms the Telegram API response into a structured photo message payload.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    # Telegram returns multiple photo sizes; pick the largest (last)
    largest_photo =
      result["photo"]
      |> List.wrap()
      |> List.last()

    {:ok,
     %{
       message_id: result["message_id"],
       chat_id: get_in(result, ["chat", "id"]),
       caption: result["caption"],
       photo_id: largest_photo && largest_photo["file_id"],
       date: result["date"]
     }}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def after_focus(%{"description" => description}) do
    {:error, description}
  end

  def after_focus(error) do
    {:error, error}
  end
end
