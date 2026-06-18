defmodule Lux.Prisms.Discord.Guilds.ManageBans do
  @moduledoc """
  A prism for managing bans in a Discord guild.

  Supports:
  - Banning a user (with optional reason and delete message days)
  - Unbanning a user
  - Listing existing bans

  ## Examples
      iex> ManageBans.handler(%{
      ...>   guild_id: "123456789",
      ...>   action: "ban",
      ...>   user_id: "987654321",
      ...>   reason: "Spamming",
      ...>   delete_message_days: 1
      ...> }, %{name: "Agent"})
      {:ok, %{
        action: "ban",
        success: true,
        user_id: "987654321",
        guild_id: "123456789"
      }}

      iex> ManageBans.handler(%{
      ...>   guild_id: "123456789",
      ...>   action: "unban",
      ...>   user_id: "987654321"
      ...> }, %{name: "Agent"})
      {:ok, %{
        action: "unban",
        success: true,
        user_id: "987654321"
      }}
  """

  use Lux.Prism,
    name: "Manage Discord Bans",
    description: "Bans, unbans, or lists bans in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to manage bans in",
          pattern: "^[0-9]{17,20}$"
        },
        action: %{
          type: :string,
          description: "Action to perform: ban, unban, or list",
          enum: ["ban", "unban", "list"]
        },
        user_id: %{
          type: :string,
          description: "The ID of the user to ban/unban (not needed for list)",
          pattern: "^[0-9]{17,20}$"
        },
        reason: %{
          type: :string,
          description: "Reason for the ban (audit log)",
          maxLength: 512
        },
        delete_message_days: %{
          type: :integer,
          description: "Number of days of messages to delete (0-7)",
          minimum: 0,
          maximum: 7,
          default: 0
        }
      },
      required: ["guild_id", "action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "The action that was performed"
        },
        success: %{
          type: :boolean,
          description: "Whether the action succeeded"
        },
        user_id: %{
          type: :string,
          description: "The ID of the affected user"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild"
        }
      },
      required: ["action", "success"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, action} <- validate_param(params, :action) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} performing ban action '#{action}' in guild #{guild_id}")

      case action do
        "ban" -> handle_ban(guild_id, params, agent_name)
        "unban" -> handle_unban(guild_id, params, agent_name)
        "list" -> handle_list_bans(guild_id, agent_name)
      end
    end
  end

  defp handle_ban(guild_id, params, agent_name) do
    with {:ok, user_id} <- validate_param(params, :user_id) do
      Logger.info("Agent #{agent_name} banning user #{user_id} from guild #{guild_id}")

      body = %{
        delete_message_days: Map.get(params, :delete_message_days, 0)
      }

      body = if reason = params[:reason], do: Map.put(body, :reason, reason), else: body

      case Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", %{json: body}) do
        {:ok, _} ->
          Logger.info("Successfully banned user #{user_id} from guild #{guild_id}")
          {:ok, %{action: "ban", success: true, user_id: user_id, guild_id: guild_id}}

        {:error, {status, %{"message" => message}}} ->
          {:error, {status, message}}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp handle_unban(guild_id, params, agent_name) do
    with {:ok, user_id} <- validate_param(params, :user_id) do
      Logger.info("Agent #{agent_name} unbanning user #{user_id} from guild #{guild_id}")

      case Client.request(:delete, "/guilds/#{guild_id}/bans/#{user_id}") do
        {:ok, _} ->
          Logger.info("Successfully unbanned user #{user_id} from guild #{guild_id}")
          {:ok, %{action: "unban", success: true, user_id: user_id, guild_id: guild_id}}

        {:error, {status, %{"message" => message}}} ->
          {:error, {status, message}}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp handle_list_bans(guild_id, agent_name) do
    Logger.info("Agent #{agent_name} listing bans for guild #{guild_id}")

    case Client.request(:get, "/guilds/#{guild_id}/bans") do
      {:ok, bans} when is_list(bans) ->
        formatted =
          Enum.map(bans, fn ban ->
            %{
              user_id: ban["user"]["id"],
              username: ban["user"]["username"],
              reason: ban["reason"]
            }
          end)

        {:ok, %{action: "list", success: true, bans: formatted, guild_id: guild_id}}

      {:error, {status, %{"message" => message}}} ->
        {:error, {status, message}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
