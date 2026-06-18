defmodule Lux.Prisms.Discord.Members.BanMember do
  @moduledoc """
  A prism for banning members from a Discord guild.

  Provides:
  - Required parameters (guild_id, user_id)
  - Optional reason and delete_message_days
  - Direct Discord API error propagation

  ## Examples
      iex> BanMember.handler(%{
      ...>   guild_id: "123456789",
      ...>   user_id: "987654321",
      ...>   reason: "Repeated violations",
      ...>   delete_message_days: 1
      ...> }, %{name: "Agent"})
      {:ok, %{
        banned: true,
        user_id: "987654321",
        guild_id: "123456789"
      }}
  """

  use Lux.Prism,
    name: "Ban Discord Member",
    description: "Bans a member from a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to ban the member from",
          pattern: "^[0-9]{17,20}$"
        },
        user_id: %{
          type: :string,
          description: "The ID of the user to ban",
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
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{
          type: :boolean,
          description: "Whether the member was successfully banned"
        },
        user_id: %{
          type: :string,
          description: "The ID of the banned user"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild"
        }
      },
      required: ["banned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} banning user #{user_id} from guild #{guild_id}")

      body = %{delete_message_days: Map.get(params, :delete_message_days, 0)}

      body =
        if reason = params[:reason] do
          Map.put(body, :reason, reason)
        else
          body
        end

      case Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", %{json: body}) do
        {:ok, _} ->
          Logger.info("Successfully banned user #{user_id} from guild #{guild_id}")
          {:ok, %{banned: true, user_id: user_id, guild_id: guild_id}}

        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to ban user #{user_id} from guild #{guild_id}: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to ban user #{user_id} from guild #{guild_id}: #{inspect(error)}")
          {:error, error}
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
