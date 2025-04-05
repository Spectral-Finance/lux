defmodule Lux.Lenses.Discord.Channels.SearchMessages do
  @moduledoc """
  A lens for searching messages in a Discord channel using keywords.

  This lens provides a simple interface for searching messages with:
  - Required parameters (channel_id, query)
  - Optional parameters (limit, offset)
  - Direct Discord API error propagation
  - Clean response structure

  ## Example
      iex> SearchMessages.focus(%{
      ...>   channel_id: "123456789",
      ...>   query: "important announcement",
      ...>   limit: 10,
      ...>   offset: 0
      ...> })
      {:ok, %{
        messages: [
          %{
            id: "987654321",
            content: "Important announcement: Server maintenance",
            author: %{
              id: "111222333",
              username: "moderator"
            },
            timestamp: "2024-04-03T12:00:00.000000+00:00",
            attachments: [],
            embeds: []
          }
        ],
        total_results: 1
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Search Messages",
    description: "Search for messages in a channel using specific keywords",
    url: "https://discord.com/api/v10/channels/:channel_id/messages/search",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to search messages in",
          pattern: "^[0-9]{17,20}$"
        },
        query: %{
          type: :string,
          description: "The search query to filter messages",
          minLength: 1
        },
        limit: %{
          type: :integer,
          description: "Maximum number of messages to return (1-100)",
          minimum: 1,
          maximum: 100,
          default: 25
        },
        offset: %{
          type: :integer,
          description: "Number of messages to skip",
          minimum: 0,
          default: 0
        }
      },
      required: ["channel_id", "query"]
    }

  @doc """
  Transforms the Discord API response into a simplified search result format.

  ## Parameters
    - response: Raw response from Discord API

  ## Returns
    - `{:ok, result}` - Search results with messages and total count
    - `{:error, reason}` - Error response from Discord API

  ## Examples
      iex> after_focus(%{
        "messages" => [[%{
          "id" => "987654321",
          "content" => "Important announcement: Server maintenance",
          "author" => %{
            "id" => "111222333",
            "username" => "moderator"
          },
          "timestamp" => "2024-04-03T12:00:00.000000+00:00",
          "attachments" => [],
          "embeds" => []
        }]],
        "total_results" => 1
      })
      {:ok, %{
        messages: [
          %{
            id: "987654321",
            content: "Important announcement: Server maintenance",
            author: %{
              id: "111222333",
              username: "moderator"
            },
            timestamp: "2024-04-03T12:00:00.000000+00:00",
            attachments: [],
            embeds: []
          }
        ],
        total_results: 1
      }}
  """
  @impl true
  def after_focus(%{"messages" => messages, "total_results" => total_results}) do
    {:ok, %{
      messages: Enum.map(messages, fn [message | _] ->
        %{
          id: message["id"],
          content: message["content"],
          author: %{
            id: message["author"]["id"],
            username: message["author"]["username"]
          },
          timestamp: message["timestamp"],
          attachments: message["attachments"],
          embeds: message["embeds"]
        }
      end),
      total_results: total_results
    }}
  end

  def after_focus(%{"message" => _} = error), do: {:error, error}
end
