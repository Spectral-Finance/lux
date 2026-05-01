defmodule Lux.Prisms.Discord.Server.JoinServer do
  @moduledoc """
  A prism for joining a Discord server via invite.

  This prism provides a simple interface for joining Discord servers with:
  - Required parameters (invite_code)
  - Optional parameters (guild_id)
  - Direct Discord API error propagation
  - Simple success/failure response structure

  ## Examples

      iex> JoinServer.handler(%{
      ...>   invite_code: "abc123",
      ...> }, %{name: "Agent"})
      {:ok, %{
        joined: true,
        guild_id: "111111111111111111",
        guild_name: "My Server"
      }}
  """

  use Lux.Prism,
    name: "Join Discord Server",
    description: "Joins a Discord server using an invite code",
    input_schema: %{
      type: :object,
      properties: %{
        invite_code: %{
          type: :string,
          description: "The invite code or URL to join the server",
          minLength: 1,
          maxLength: 100
        }
      },
      required: ["invite_code"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        joined: %{
          type: :boolean,
          description: "Whether the server was successfully joined"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the joined server"
        },
        guild_name: %{
          type: :string,
          description: "The name of the joined server"
        }
      },
      required: ["joined"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to join a Discord server.

  Returns {:ok, %{joined: true, guild_id: id, guild_name: name}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, invite_code} <- validate_param(params, :invite_code) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} joining server with invite code")

      case Client.request(:post, "/invites/#{invite_code}", %{}) do
        {:ok, %{"guild" => %{"id" => guild_id, "name" => guild_name}}} ->
          Logger.info("Successfully joined server #{guild_name} (#{guild_id})")
          {:ok, %{joined: true, guild_id: guild_id, guild_name: guild_name}}

        {:ok, response} ->
          Logger.info("Joined server with response: #{inspect(response)}")
          {:ok, %{joined: true, guild_id: response["guild"]["id"] || "unknown", guild_name: response["guild"]["name"] || "unknown"}}

        error ->
          Logger.error("Failed to join server: #{inspect(error)}")
          error
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
