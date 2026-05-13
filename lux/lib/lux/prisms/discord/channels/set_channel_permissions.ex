defmodule Lux.Prisms.Discord.Channels.SetChannelPermissions do
  @moduledoc """
  A prism for creating or updating Discord channel permission overwrites.

  `overwrite_type` follows Discord's API: `0` for role overwrites, `1` for
  member overwrites. `allow` and `deny` are Discord permission bitset strings.
  """

  use Lux.Prism,
    name: "Set Discord Channel Permissions",
    description: "Creates or updates a Discord channel permission overwrite",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        overwrite_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        overwrite_type: %{type: :integer, enum: [0, 1]},
        allow: %{type: :string, description: "Allowed permission bitset"},
        deny: %{type: :string, description: "Denied permission bitset"},
        reason: %{type: :string}
      },
      required: ["channel_id", "overwrite_id", "overwrite_type", "allow", "deny"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{type: :boolean},
        channel_id: %{type: :string},
        overwrite_id: %{type: :string}
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- Helpers.validate_string(params, :channel_id),
         {:ok, overwrite_id} <- Helpers.validate_string(params, :overwrite_id),
         {:ok, overwrite_type} <- Helpers.validate_integer(params, :overwrite_type),
         {:ok, allow} <- Helpers.validate_string(params, :allow),
         {:ok, deny} <- Helpers.validate_string(params, :deny) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting permissions #{overwrite_id} in #{channel_id}")

      payload = %{type: overwrite_type, allow: allow, deny: deny}
      opts = Helpers.client_opts(params, %{json: payload})

      case Client.request_with_retry(:put, "/channels/#{channel_id}/permissions/#{overwrite_id}", opts) do
        {:ok, _} ->
          {:ok, %{updated: true, channel_id: channel_id, overwrite_id: overwrite_id}}

        error ->
          Logger.error("Failed to set Discord channel permissions: #{inspect(error)}")
          error
      end
    end
  end
end
