defmodule Lux.Prisms.Discord.Thread.ListThreads do
  @moduledoc """
  A prism for listing active threads in a Discord channel.

  Returns all active and archived threads in a forum or text channel.
  """

  use Lux.Prism,
    name: "List Discord Threads",
    description: "Lists all threads in a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to list threads for",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        threads: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              name: %{type: :string},
              archived: %{type: :boolean},
              auto_archive_duration: %{type: :integer},
              thread_metadata: %{type: :object},
              owner_id: %{type: :string},
              parent_id: %{type: :string}
            }
          }
        }
      },
      required: ["threads"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Lists all threads in a Discord channel.
  """
  def handler(params, agent) do
      with {:ok, channel_id} <- Lux.Prisms.Discord.Helpers.validate_string(params, :channel_id) do
        agent_name = agent[:name] || "Unknown Agent"
        Logger.info("Agent #{agent_name} listing threads in channel #{channel_id}")

        case Client.request(:get, Lux.Prisms.Discord.Helpers.client_opts(params, max_retries: 2)) do
        {:ok, %{"threads" => threads}} ->
          Logger.info("Found #{length(threads)} threads in channel #{channel_id}")
          {:ok, %{threads: threads}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to list threads in channel #{channel_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to list threads in channel #{channel_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end
end