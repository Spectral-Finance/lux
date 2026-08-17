defmodule Lux.Prisms.Discord.Channels.ArchiveChannel do
  @moduledoc """
  A prism for archiving a Discord channel (forum/stage/voice thread).

  Sets archived=true and optionally locked=true.
  """

  use Lux.Prism,
    name: "Archive Discord Channel",
    description: "Archives a Discord thread/channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        lock: %{type: :boolean, default: true, description: "Also lock the thread when archiving"},
        reason: %{type: :string}
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        archived: %{type: :boolean},
        channel_id: %{type: :string},
        locked: %{type: :boolean}
      },
      required: ["archived", "channel_id", "locked"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @doc """
  Archives a Discord channel/thread.

  Returns {:ok, %{archived: true, channel_id: ..., locked: ...}}.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- Helpers.validate_string(params, :channel_id),
         {:ok, lock} <- Helpers.optional(params, :lock, true) do

      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} archiving channel #{channel_id} (lock: #{lock})")

      payload = %{archived: true}
      if lock, do: payload = Map.put(payload, :locked, true)

      opts = Helpers.client_opts(params, %{json: payload})

      case Client.request_with_retry(:patch, "/channels/#{channel_id}", opts) do
        {:ok, response} ->
          {:ok, %{
            archived: Map.get(response, "archived", true),
            channel_id: Map.get(response, "id", channel_id),
            locked: Map.get(response, "locked", lock)
          }}

        error ->
          Logger.error("Failed to archive channel #{channel_id}: #{inspect(error)}")
          error
      end
    end
  end
end