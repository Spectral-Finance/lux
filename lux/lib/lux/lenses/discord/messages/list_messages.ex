defmodule Lux.Lenses.Discord.Messages.ListMessages do
  @moduledoc """
  A lens for listing messages from a Discord channel.
  This lens provides a simple interface for fetching messages with:
  - Minimal required parameters (channel_id)
  - Direct Discord API error propagation
  - Clean response structure
  ## Examples
      iex> ListMessages.focus(%{
      ...>   channel_id: "123456789"
      ...> })
      {:ok, [
        %{
          content: "First message",
          author: %{
            id: "111222333",
            username: "TestUser1"
          }
        },
        %{
          content: "Second message",
          author: %{
            id: "444555666",
            username: "TestUser2"
          }
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Messages",
    description: "Lists messages from a Discord channel",
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
