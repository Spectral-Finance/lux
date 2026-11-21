defmodule Lux.Prisms.Discord.Moderation.UnbanMember do
  @moduledoc """
  A prism for removing a ban from a Discord guild member.

  Implements the ModerationPrism requirements of lux issue #57: unbanning a
  previously banned user.

  ## Examples
      iex> UnbanMember.handler(%{
      ...>   guild_id: "123456789012345678",
      ...>   user_id: "987654321098765432",
      ...>   reason: "Appeal accepted"
      ...> }, %{name: "Agent"})
      {:ok, %{unbanned: true, guild_id: "123456789012345678", user_id: "987654321098765432"}}
  """

  use Lux.Prism,
    name: "Unban Discord Member",
    description: "Removes a ban from a user in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The ID of the guild", pattern: "^[0-9]{17,20}$"},
        user_id: %{
          type: :string,
          description: "The ID of the user to unban",
          pattern: "^[0-9]{17,20}$"
        },
        reason: %{type: :string, description: "Optional audit-log reason"}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        unbanned: %{type: :boolean, description: "Whether the user was unbanned"},
        guild_id: %{type: :string, description: "The guild ID"},
        user_id: %{type: :string, description: "The unbanned user ID"}
      },
      required: ["unbanned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_id(params, :guild_id),
         {:ok, user_id} <- validate_id(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"

      Logger.info("Agent #{agent_name} unbanning user #{user_id} in guild #{guild_id}")

      opts = build_opts(params)

      case Client.request(:delete, "/guilds/#{guild_id}/bans/#{user_id}", opts) do
        {:ok, _body} ->
          Logger.info("Successfully unbanned user #{user_id} in guild #{guild_id}")

          {:ok, %{unbanned: true, guild_id: guild_id, user_id: user_id}}

        {:error, {status, %{"message" => message}}} ->
          Logger.error("Failed to unban user #{user_id}: #{inspect({status, message})}")
          {:error, {status, message}}

        {:error, error} ->
          Logger.error("Failed to unban user #{user_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp build_opts(params) do
    case Map.fetch(params, :reason) do
      {:ok, reason} when is_binary(reason) and reason != "" ->
        %{params: %{reason: reason}}

      _ ->
        %{}
    end
  end

  defp validate_id(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
