defmodule Lux.Lenses.Discord.Messages.ReadMessage do
  @moduledoc """
  A lens for reading messages from Discord channels.
  This lens provides a simple interface for reading Discord messages with:
  - Minimal required parameters (channel_id, message_id)
  - Direct Discord API error propagation
  - Clean response structure
  ## Examples
      iex> ReadMessage.focus(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321"
      ...> })
      {:ok, %{
        content: "Hello, world!",
        author: %{
          id: "111222333",
          username: "TestUser"
        }
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Read Discord Message",
    description: "Reads a message from a Discord channel",
    url: "https://discord.com/api/v10/channels/:channel_id/messages/:message_id",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the message",
          pattern: "^[0-9]{17,20}$"
        },
        message_id: %{
          type: :string,
          description: "The ID of the message to read",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id", "message_id"]
    }

  @doc """
  Transforms the Discord API response into a simpler format.
  ## Examples
      iex> after_focus(%{
      ...>   "content" => "Hello!",
      ...>   "author" => %{"id" => "123", "username" => "test"}
      ...> })
      {:ok, %{
        content: "Hello!",
        author: %{id: "123", username: "test"}
      }}
  """
  @impl true
  def after_focus(%{"content" => content, "author" => author}) do
    {:ok, %{
      content: content,
      author: %{
        id: author["id"],
        username: author["username"]
      }
    }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
