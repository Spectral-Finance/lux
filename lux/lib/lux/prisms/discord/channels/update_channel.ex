defmodule Lux.Prisms.Discord.Channels.UpdateChannel do
  @moduledoc """
  A prism for updating Discord channel configuration.

  Supports common text/voice/forum channel fields and leaves Discord API error
  responses intact for agents to inspect.
  """

  use Lux.Prism,
    name: "Update Discord Channel",
    description: "Updates Discord channel name, topic, parent, slowmode, NSFW, or archive settings",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        name: %{type: :string, minLength: 1, maxLength: 100},
        topic: %{type: :string, maxLength: 1024},
        nsfw: %{type: :boolean},
        rate_limit_per_user: %{type: :integer, minimum: 0, maximum: 21_600},
        parent_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        archived: %{type: :boolean},
        locked: %{type: :boolean},
        reason: %{type: :string}
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{type: :boolean},
        channel_id: %{type: :string},
        payload: %{type: :object}
      },
      required: ["updated", "channel_id"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @fields [:name, :topic, :nsfw, :rate_limit_per_user, :parent_id, :archived, :locked]

  def handler(params, agent) do
    with {:ok, channel_id} <- Helpers.validate_string(params, :channel_id),
         {:ok, payload} <- params |> Helpers.take_optional(@fields) |> Helpers.non_empty_payload() do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} updating Discord channel #{channel_id}")

      opts = Helpers.client_opts(params, %{json: payload})

      case Client.request_with_retry(:patch, "/channels/#{channel_id}", opts) do
        {:ok, response} ->
          {:ok, %{updated: true, channel_id: Map.get(response, "id", channel_id), payload: payload}}

        error ->
          Logger.error("Failed to update Discord channel #{channel_id}: #{inspect(error)}")
          error
      end
    end
  end
end
