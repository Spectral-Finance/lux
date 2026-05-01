defmodule Lux.Prisms.Discord.Members.BanMember do
  @moduledoc """
  A prism for banning a member from a Discord server.

  ## Examples

      iex> BanMember.handler(%{
      ...>   guild_id: "111111111111111111",
      ...>   user_id: "222222222222222222",
      ...>   delete_message_days: 1,
      ...>   reason: "Severe violation"
      ...> }, %{name: "Agent"})
      {:ok, %{banned: true, user_id: "222222222222222222", guild_id: "111111111111111111"}}
  """

  use Lux.Prism,
    name: "Ban Discord Member",
    description: "Bans a member from a Discord server",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the server",
          pattern: "^[0-9]{17,20}$"
        },
        user_id: %{
          type: :string,
          description: "The ID of the user to ban",
          pattern: "^[0-9]{17,20}$"
        },
        delete_message_days: %{
          type: :integer,
          description: "Number of days of messages to delete (0-7)",
          minimum: 0,
          maximum: 7,
          default: 0
        },
        reason: %{
          type: :string,
          description: "Optional audit log reason for the ban",
          maxLength: 500
        }
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{type: :boolean, description: "Whether the member was successfully banned"},
        user_id: %{type: :string, description: "The ID of the banned user"},
        guild_id: %{type: :string, description: "The ID of the server"}
      },
      required: ["banned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, delete_message_days} <- validate_optional_param(params, :delete_message_days, 0) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} banning user #{user_id} from server #{guild_id}")

      body = %{delete_message_days: delete_message_days}

      case Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", %{json: body}) do
        {:ok, _} ->
          {:ok, %{banned: true, user_id: user_id, guild_id: guild_id}}
        {:error, %{"status" => 204}} ->
          {:ok, %{banned: true, user_id: user_id, guild_id: guild_id}}
        error ->
          Logger.error("Failed to ban member: #{inspect(error)}")
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

  defp validate_optional_param(params, key, default \\ nil) do
    case Map.get(params, key, default) do
      nil -> {:ok, nil}
      value -> {:ok, value}
    end
  end
end
