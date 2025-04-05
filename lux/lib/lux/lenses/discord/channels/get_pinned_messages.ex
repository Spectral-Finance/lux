defmodule Lux.Lenses.Discord.Channels.GetPinnedMessages do
  @moduledoc """
  A lens for retrieving pinned messages from a Discord channel.

  This lens provides a simple interface for fetching pinned messages with:
  - Minimal required parameters (channel_id)
  - Direct Discord API error propagation
  - Clean response structure

  ## Example
      iex> GetPinnedMessages.focus(%{channel_id: "123456789"})
      {:ok, [
        %{
          id: "987654321",
          content: "Important announcement!",
          author: %{
            id: "111222333",
            username: "moderator"
          },
          timestamp: "2024-04-03T12:00:00.000000+00:00",
          pinned: true,
          attachments: [],
          embeds: []
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Pinned Messages",
    description: "Fetch pinned messages in a channel",
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

  @doc """
  Transforms the Discord API response into a simplified message list format.

  ## Parameters
    - response: Raw response from Discord API

  ## Returns
    - `{:ok, messages}` - List of pinned messages
    - `{:error, reason}` - Error response from Discord API

  ## Examples
      iex> after_focus([
        %{
          "id" => "987654321",
          "content" => "Important announcement!",
          "author" => %{
            "id" => "111222333",
            "username" => "moderator"
          },
          "timestamp" => "2024-04-03T12:00:00.000000+00:00",
          "pinned" => true,
          "attachments" => [],
          "embeds" => []
        }
      ])
      {:ok, [
        %{
          id: "987654321",
          content: "Important announcement!",
          author: %{
            id: "111222333",
            username: "moderator"
          },
          timestamp: "2024-04-03T12:00:00.000000+00:00",
          pinned: true,
          attachments: [],
          embeds: []
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
        pinned: message["pinned"],
        attachments: message["attachments"],
        embeds: message["embeds"]
      }
    end)}
  end

  def after_focus(%{"message" => _} = error), do: {:error, error}
end
