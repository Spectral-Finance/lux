defmodule Lux.Prisms.Discord.Channels.CreateChannel do
  @moduledoc """
  A prism for creating channels in a Discord guild.

  This prism provides a simple interface for creating Discord channels with:
  - Required parameters (guild_id, name, type)
  - Direct Discord API error propagation
  - Simple success/failure response structure

  ## Examples
      iex> CreateChannel.handler(%{
      ...>   guild_id: "123456789",
      ...>   name: "general",
      ...>   type: 0
      ...> }, %{name: "Agent"})
      {:ok, %{
        created: true,
        channel_id: "111111111111111111",
        name: "general",
        type: 0,
        guild_id: "123456789"
      }}
  """

  use Lux.Prism,
    name: "Create Discord Channel",
    description: "Creates a new channel in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to create the channel in",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "The name of the channel (1-100 characters)",
          minLength: 1,
          maxLength: 100,
          pattern: "^[\\w-]+$"
        },
        type: %{
          type: :integer,
          description: "The type of channel (0: text, 2: voice, 13: stage, 15: forum)",
          enum: [0, 2, 13, 15]
        }
      },
      required: ["guild_id", "name", "type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{
          type: :boolean,
          description: "Whether the channel was successfully created"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the created channel"
        },
        name: %{
          type: :string,
          description: "The name of the created channel"
        },
        type: %{
          type: :integer,
          description: "The type of the created channel"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild where the channel was created"
        }
      },
      required: ["created"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to create a channel in a Discord guild.

  Returns {:ok, %{created: true, channel_id: id, name: name, type: type, guild_id: guild_id}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, name} <- validate_param(params, :name),
         {:ok, type} <- validate_param(params, :type) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating channel #{name} in guild #{guild_id}")

      case Client.request(:post, "/guilds/#{guild_id}/channels", %{json: %{
        name: name,
        type: type
      }}) do
        {:ok, %{"id" => channel_id, "name" => name, "type" => type, "guild_id" => guild_id}} ->
          Logger.info("Successfully created channel #{channel_id} in guild #{guild_id}")
          {:ok, %{created: true, channel_id: channel_id, name: name, type: type, guild_id: guild_id}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to create channel in guild #{guild_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to create channel in guild #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
