defmodule Lux.Lenses.Discord.Messages.ListMessages do
  @moduledoc """
  A lens for listing messages from a Discord channel.
  This lens provides a simple interface for fetching messages with:
  - Minimal required parameters (channel_id)
  - Pagination support (limit, before, after, around)
  - Direct Discord API error propagation
  - Clean response structure

  ## Pagination
  The lens supports the following pagination parameters:
  - limit: Number of messages to return (1-100, default 50)
  - before: Get messages before this message ID
  - after: Get messages after this message ID
  - around: Get messages around this message ID

  Note: Only one of before, after, or around should be specified.

  ## Examples
      # Get latest 50 messages
      iex> ListMessages.focus(%{
      ...>   channel_id: "123456789"
      ...> })

      # Get 100 messages before a specific message
      iex> ListMessages.focus(%{
      ...>   channel_id: "123456789",
      ...>   limit: 100,
      ...>   before: "111222333"
      ...> })

      # Get 25 messages around a specific message
      iex> ListMessages.focus(%{
      ...>   channel_id: "123456789",
      ...>   limit: 25,
      ...>   around: "111222333"
      ...> })
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Messages",
    description: "Lists messages from a Discord channel with pagination support",
    url: "https://discord.com/api/v10/channels/:channel_id/messages",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to list messages from",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Max number of messages to return (1-100)",
          minimum: 1,
          maximum: 100,
          default: 50
        },
        before: %{
          type: :string,
          description: "Get messages before this message ID",
          pattern: "^[0-9]{17,20}$"
        },
        after: %{
          type: :string,
          description: "Get messages after this message ID",
          pattern: "^[0-9]{17,20}$"
        },
        around: %{
          type: :string,
          description: "Get messages around this message ID",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    }

  @doc """
  Transforms the Discord API response into a simpler format.
  ## Examples
      iex> after_focus([
      ...>   %{
      ...>     "content" => "Hello!",
      ...>     "author" => %{"id" => "123", "username" => "test"}
      ...>   }
      ...> ])
      {:ok, [
        %{
          content: "Hello!",
          author: %{id: "123", username: "test"}
        }
      ]}
  """
  @impl true
  def after_focus(messages) when is_list(messages) do
    {:ok, Enum.map(messages, fn %{"content" => content, "author" => author} ->
      %{
        content: content,
        author: %{
          id: author["id"],
          username: author["username"]
        }
      }
    end)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
