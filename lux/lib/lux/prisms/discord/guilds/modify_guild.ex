defmodule Lux.Prisms.Discord.Guilds.ModifyGuild do
  @moduledoc """
  A prism for modifying Discord guild (server) settings.

  Supports updating:
  - Name, description, icon
  - Verification level, notification settings
  - System channel, AFK channel, safety settings

  ## Examples
      iex> ModifyGuild.handler(%{
      ...>   guild_id: "123456789",
      ...>   name: "Updated Server Name",
      ...>   description: "A better description"
      ...> }, %{name: "Agent"})
      {:ok, %{
        modified: true,
        guild_id: "123456789",
        name: "Updated Server Name"
      }}
  """

  use Lux.Prism,
    name: "Modify Discord Guild",
    description: "Modifies settings of a Discord guild (server)",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to modify",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "New guild name (1-100 characters)",
          minLength: 1,
          maxLength: 100
        },
        description: %{
          type: :string,
          description: "New guild description (0-1024 characters)",
          maxLength: 1024
        },
        verification_level: %{
          type: :integer,
          description: "Verification level (0: none, 1: low, 2: medium, 3: high, 4: very high)",
          enum: [0, 1, 2, 3, 4]
        },
        default_message_notifications: %{
          type: :integer,
          description: "Default notification level (0: all, 1: only mentions)",
          enum: [0, 1]
        },
        system_channel_id: %{
          type: :string,
          description: "ID of the system message channel",
          pattern: "^[0-9]{17,20}$"
        },
        afk_channel_id: %{
          type: :string,
          description: "ID of the AFK voice channel",
          pattern: "^[0-9]{17,20}$"
        },
        afk_timeout: %{
          type: :integer,
          description: "AFK timeout in seconds (60, 300, 900, 1800, 3600)",
          enum: [60, 300, 900, 1800, 3600]
        }
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        modified: %{
          type: :boolean,
          description: "Whether the guild was successfully modified"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the modified guild"
        },
        name: %{
          type: :string,
          description: "The updated name of the guild"
        }
      },
      required: ["modified"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} modifying guild #{guild_id}")

      body = build_request_body(params)

      case Client.request(:patch, "/guilds/#{guild_id}", %{json: body}) do
        {:ok, %{"id" => id, "name" => name}} ->
          Logger.info("Successfully modified guild #{guild_id}")
          {:ok, %{modified: true, guild_id: id, name: name}}

        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to modify guild #{guild_id}: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to modify guild #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp build_request_body(params) do
    fields = [:name, :description, :verification_level, :default_message_notifications,
              :system_channel_id, :afk_channel_id, :afk_timeout]

    Enum.reduce(fields, %{}, fn field, acc ->
      case Map.fetch(params, field) do
        {:ok, value} when not is_nil(value) -> Map.put(acc, field, value)
        _ -> acc
      end
    end)
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
