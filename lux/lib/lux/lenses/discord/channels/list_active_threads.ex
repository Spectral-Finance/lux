defmodule Lux.Lenses.Discord.Channels.ListActiveThreads do
  @moduledoc """
  Lists active threads in a Discord channel.

  This lens provides a simple interface for fetching active threads with:
  - Minimal required parameters (channel_id)
  - Direct Discord API error propagation
  - Clean response structure

  ## Example
      iex> ListActiveThreads.focus(%{channel_id: "123456789"})
      {:ok, [
        %{
          id: "987654321",
          name: "discussion-thread",
          owner_id: "111222333",
          parent_id: "123456789",
          message_count: 50,
          member_count: 5,
          thread_metadata: %{
            archived: false,
            auto_archive_duration: 1440,
            archive_timestamp: "2024-04-03T12:00:00.000000+00:00",
            locked: false
          }
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Active Threads",
    description: "Fetch a list of active threads in a channel",
    url: "https://discord.com/api/v10/channels/:channel_id/threads/active",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to list active threads from",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    }

  @doc """
  Transforms the Discord API response into a simplified thread list format.

  ## Parameters
    - response: Raw response from Discord API

  ## Returns
    - `{:ok, threads}` - List of active threads with their metadata
    - `{:error, reason}` - Error response from Discord API

  ## Examples
      iex> after_focus(%{
        "threads" => [
          %{
            "id" => "987654321",
            "name" => "discussion-thread",
            "owner_id" => "111222333",
            "parent_id" => "123456789",
            "message_count" => 50,
            "member_count" => 5,
            "thread_metadata" => %{
              "archived" => false,
              "auto_archive_duration" => 1440,
              "archive_timestamp" => "2024-04-03T12:00:00.000000+00:00",
              "locked" => false
            }
          }
        ]
      })
      {:ok, [
        %{
          id: "987654321",
          name: "discussion-thread",
          owner_id: "111222333",
          parent_id: "123456789",
          message_count: 50,
          member_count: 5,
          thread_metadata: %{
            archived: false,
            auto_archive_duration: 1440,
            archive_timestamp: "2024-04-03T12:00:00.000000+00:00",
            locked: false
          }
        }
      ]}
  """
  @impl true
  def after_focus(%{"threads" => threads}) do
    {:ok, Enum.map(threads, fn thread ->
      %{
        id: thread["id"],
        name: thread["name"],
        owner_id: thread["owner_id"],
        parent_id: thread["parent_id"],
        message_count: thread["message_count"],
        member_count: thread["member_count"],
        thread_metadata: %{
          archived: thread["thread_metadata"]["archived"],
          auto_archive_duration: thread["thread_metadata"]["auto_archive_duration"],
          archive_timestamp: thread["thread_metadata"]["archive_timestamp"],
          locked: thread["thread_metadata"]["locked"]
        }
      }
    end)}
  end

  def after_focus(%{"message" => _} = error), do: {:error, error}
end
