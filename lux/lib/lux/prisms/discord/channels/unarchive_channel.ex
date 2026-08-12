defmodule Lux.Prisms.Discord.Channels.UnarchiveChannel do
  @moduledoc """
  A prism for unarchiving a Discord channel (forum/stage/voice thread).

  Sets archived=false and locked=false.
  """

  use Lux.Prism,
    name: "Unarchive Discord Channel",
    description: "Unarchives a Discord thread/channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
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
  Unarchives a Discord channel/thread.

  Returns {:ok, %{archived: false, channel_id: ..., locked: false}}.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- Helpers.validate_string(params, :channel_id) do

      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} unarchiving channel #{channel_id}")

      payload = %{archived: false, locked: false}
      opts = Helpers.client_opts(params, %{json: payload})

      case Client.request_with_retry(:patch, "/channels/#{channel_id}", opts) do
        {:ok, response} ->
          {:ok, %{
            archived: Map.get(response, "archived", false),
            channel_id: Map.get(response, "id", channel_id),
            locked: Map.get(response, "locked", false)
          }}

        error ->
          Logger.error("Failed to unarchive channel #{channel_id}: #{inspect(error)}")
          error
      end
    end
  end
end