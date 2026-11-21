defmodule Lux.Prisms.Discord.Moderation.BanMember do
  @moduledoc """
  A prism for banning a member from a Discord guild.

  Implements the ModerationPrism requirements of lux issue #57: member bans
  with optional message-deletion window and audit-log reason.

  ## Examples
      iex> BanMember.handler(%{
      ...>   guild_id: "123456789012345678",
      ...>   user_id: "987654321098765432",
      ...>   delete_message_seconds: 86400,
      ...>   reason: "Repeated violations"
      ...> }, %{name: "Agent"})
      {:ok, %{banned: true, guild_id: "123456789012345678", user_id: "987654321098765432"}}
  """

  use Lux.Prism,
    name: "Ban Discord Member",
    description: "Bans a member from a Discord guild with optional message deletion",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The ID of the guild", pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, description: "The ID of the member to ban", pattern: "^[0-9]{17,20}$"},
        delete_message_seconds: %{
          type: :integer,
          description: "Seconds of recent messages to delete (0-604800)",
          minimum: 0,
          maximum: 604_800
        },
        reason: %{type: :string, description: "Optional audit-log reason"}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{type: :boolean, description: "Whether the member was banned"},
        guild_id: %{type: :string, description: "The guild ID"},
        user_id: %{type: :string, description: "The banned member ID"}
      },
      required: ["banned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_id(params, :guild_id),
         {:ok, user_id} <- validate_id(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"

      Logger.info("Agent #{agent_name} banning member #{user_id} from guild #{guild_id}")

      opts = build_opts(params)

      case Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", opts) do
        {:ok, _body} ->
          Logger.info("Successfully banned member #{user_id} from guild #{guild_id}")

          {:ok, %{banned: true, guild_id: guild_id, user_id: user_id}}

        {:error, {status, %{"message" => message}}} ->
          Logger.error("Failed to ban member #{user_id}: #{inspect({status, message})}")
          {:error, {status, message}}

        {:error, error} ->
          Logger.error("Failed to ban member #{user_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp build_opts(params) do
    opts = %{}

    opts =
      case Map.fetch(params, :delete_message_seconds) do
        {:ok, seconds} when is_integer(seconds) and seconds > 0 ->
          Map.put(opts, :params, %{delete_message_seconds: seconds})

        _ ->
          opts
      end

    case Map.fetch(params, :reason) do
      {:ok, reason} when is_binary(reason) and reason != "" ->
        Map.update(opts, :params, %{reason: reason}, fn existing ->
          Map.put(existing, :reason, reason)
        end)

      _ ->
        opts
    end
  end

  defp validate_id(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end