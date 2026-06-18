defmodule Lux.Lenses.Discord.Messages.SearchMessages do
  @moduledoc """
  A lens for searching messages across a Discord guild.

  Uses Discord's search endpoint with support for:
  - Content search with natural language queries
  - Filtering by author, channel, date range
  - Pagination with limit and offset

  ## Examples
      iex> SearchMessages.focus(%{
      ...>   guild_id: "123456789",
      ...>   content: "hello",
      ...>   author_id: "987654321",
      ...>   limit: 25
      ...> })
      {:ok, [
        %{
          id: "111111111111111111",
          content: "hello world",
          author: %{id: "987654321", username: "Alice"},
          channel_id: "555555555555555555",
          timestamp: "2024-01-01T00:00:00Z"
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Search Discord Messages",
    description: "Searches messages across a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/messages/search",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to search messages in",
          pattern: "^[0-9]{17,20}$"
        },
        content: %{
          type: :string,
          description: "Search query to find messages by content"
        },
        author_id: %{
          type: :string,
          description: "Filter messages by author user ID"
        },
        channel_id: %{
          type: :string,
          description: "Filter messages by channel ID",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Number of results to return (1-100)",
          minimum: 1,
          maximum: 100,
          default: 25
        },
        offset: %{
          type: :integer,
          description: "Offset for pagination",
          minimum: 0,
          default: 0
        }
      },
      required: ["guild_id"]
    }

  @impl true
  def before_focus(params) do
    params
    |> Map.drop([:guild_id])
    |> Enum.reduce(%{}, fn
      {:content, value}, acc -> Map.put(acc, :content, value)
      {:author_id, value}, acc -> Map.put(acc, :author_id, value)
      {:channel_id, value}, acc -> Map.put(acc, :channel_id, value)
      {:limit, value}, acc -> Map.put(acc, :limit, value)
      {:offset, value}, acc -> Map.put(acc, :offset, value)
      _, acc -> acc
    end)
  end

  @impl true
  def after_focus(%{"messages" => results, "total_results" => total}) do
    messages =
      Enum.map(results, fn [message | _] ->
        %{
          id: message["id"],
          content: message["content"],
          author: %{
            id: message["author"]["id"],
            username: message["author"]["username"],
            avatar: message["author"]["avatar"]
          },
          channel_id: message["channel_id"],
          timestamp: message["timestamp"],
          edited_timestamp: message["edited_timestamp"],
          pinned: message["pinned"],
          mention_everyone: message["mention_everyone"]
        }
      end)

    {:ok, %{messages: messages, total_results: total}}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
