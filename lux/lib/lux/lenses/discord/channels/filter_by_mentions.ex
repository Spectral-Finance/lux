defmodule Lux.Lenses.Discord.Channels.FilterByMentions do
  @moduledoc """
  A lens for retrieving messages that mention specific users in a Discord channel.

  This lens provides a simple interface for filtering messages with:
  - Required parameters (channel_id, mentioned_user_ids)
  - Optional parameters (limit, before, after)
  - Direct Discord API error propagation
  - Clean response structure

  ## Example
      iex> FilterByMentions.focus(%{
      ...>   channel_id: "123456789",
      ...>   mentioned_user_ids: ["111222333"],
      ...>   limit: 50
      ...> })
      {:ok, [
        %{
          id: "987654321",
          content: "Hey <@111222333>, please check this out!",
          author: %{
            id: "444555666",
            username: "team_lead"
          },
          timestamp: "2024-04-03T12:00:00.000000+00:00",
          mentions: [
            %{
              id: "111222333",
              username: "developer"
            }
          ]
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Filter by Mentions",
    description: "Retrieve messages that mention specific users",
    url: "https://discord.com/api/v10/channels/:channel_id/messages",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to filter messages in",
          pattern: "^[0-9]{17,20}$"
        },
        mentioned_user_ids: %{
          type: :array,
          description: "List of user IDs to filter mentions by (currently only supports one user)",
          items: %{
            type: :string,
            pattern: "^[0-9]{17,20}$"
          },
          minItems: 1,
          maxItems: 1
        },
        limit: %{
          type: :integer,
          description: "Maximum number of messages to return (1-100)",
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
        }
      },
      required: ["channel_id", "mentioned_user_ids"]
    }

  @doc """
  Transforms the Discord API response into a simplified message list format.

  ## Parameters
    - response: Raw response from Discord API

  ## Returns
    - `{:ok, messages}` - List of messages mentioning specified users
    - `{:error, reason}` - Error response from Discord API

  ## Examples
      iex> after_focus([
      ...>   %{
      ...>     "id" => "987654321",
      ...>     "content" => "Hey <@111222333>, please check this out!",
      ...>     "author" => %{
      ...>       "id" => "444555666",
      ...>       "username" => "team_lead"
      ...>     },
      ...>     "timestamp" => "2024-04-03T12:00:00.000000+00:00",
      ...>     "mentions" => [
      ...>       %{
      ...>         "id" => "111222333",
      ...>         "username" => "developer"
      ...>       }
      ...>     ]
      ...>   }
      ...> ])
      {:ok, [
        %{
          id: "987654321",
          content: "Hey <@111222333>, please check this out!",
          author: %{
            id: "444555666",
            username: "team_lead"
          },
          timestamp: "2024-04-03T12:00:00.000000+00:00",
          mentions: [
            %{
              id: "111222333",
              username: "developer"
            }
          ]
        }
      ]}
  """
  @impl true
  def after_focus(messages) when is_list(messages) do
    {:ok, Enum.map(messages, fn message ->
      %{
        id: message["id"],
        content: message["content"],
        author: %{
          id: message["author"]["id"],
          username: message["author"]["username"]
        },
        timestamp: message["timestamp"],
        mentions: Enum.map(message["mentions"], fn mention ->
          %{
            id: mention["id"],
            username: mention["username"]
          }
        end)
      }
    end)}
  end

  def after_focus(%{"message" => message}), do: {:error, %{"message" => message}}

  @doc """
  Prepares the request parameters by converting the mentioned_user_ids list into a query parameter.
  Ensures correct parameter order by using a keyword list.
  """
  def before_focus(%{mentioned_user_ids: [user_id | _], limit: limit}) do
    [mentions: user_id, limit: limit]
  end

  def before_focus(%{mentioned_user_ids: [user_id | _]}) do
    [mentions: user_id, limit: 50]
  end
end
