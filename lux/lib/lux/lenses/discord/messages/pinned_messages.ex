defmodule Lux.Lenses.Discord.Messages.PinnedMessages do
  @moduledoc """
  A lens for listing pinned messages in a Discord channel.

  Returns all pinned messages with:
  - Message content and author info
  - Pin timestamp
  - Clean response structure

  ## Examples
      iex> PinnedMessages.focus(%{
      ...>   channel_id: "123456789"
      ...> })
      {:ok, [
        %{
          id: "111111111111111111",
          content: "Important announcement",
          author: %{id: "987654321", username: "Admin"},
          pinned_at: "2024-01-01T00:00:00Z"
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Pinned Discord Messages",
    description: "Lists pinned messages from a Discord channel",
    url: "https://discord.com/api/v10/channels/:channel_id/pins",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to get pinned messages from",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    }

  @impl true
  def after_focus(messages) when is_list(messages) do
    {:ok,
     Enum.map(messages, fn msg ->
       %{
         id: msg["id"],
         content: msg["content"],
         author: %{
           id: msg["author"]["id"],
           username: msg["author"]["username"],
           avatar: msg["author"]["avatar"]
         },
         channel_id: msg["channel_id"],
         timestamp: msg["timestamp"],
         pinned_at: msg["pinned_at"],
         mentions: msg["mentions"]
       }
     end)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
