defmodule Lux.Prisms.Discord.Moderation.BanMember do
  @moduledoc """
  Bans a Discord guild member.
  """

  use Lux.Prism,
    name: "Ban Discord Member",
    description: "Bans a user from a Discord guild with optional audit log reason",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Discord guild ID", pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, description: "Discord user ID", pattern: "^[0-9]{17,20}$"},
        delete_message_seconds: %{
          type: :integer,
          description: "Seconds of prior messages Discord should delete",
          minimum: 0,
          maximum: 604_800
        },
        reason: %{type: :string, description: "Optional Discord audit log reason"}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{type: :boolean, description: "Whether the user was banned"},
        guild_id: %{type: :string, description: "Discord guild ID"},
        user_id: %{type: :string, description: "Discord user ID"}
      },
      required: ["banned"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(params, _agent) do
    with {:ok, guild_id} <- validate_string(params, :guild_id),
         {:ok, user_id} <- validate_string(params, :user_id),
         {:ok, delete_message_seconds} <-
           validate_delete_seconds(Map.get(params, :delete_message_seconds, 0)) do
      opts = %{
        json: %{delete_message_seconds: delete_message_seconds},
        headers: audit_headers(params[:reason])
      }

      case Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", opts) do
        {:ok, _response} -> {:ok, %{banned: true, guild_id: guild_id, user_id: user_id}}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp validate_string(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_delete_seconds(value) when is_integer(value) and value >= 0 and value <= 604_800,
    do: {:ok, value}

  defp validate_delete_seconds(_value), do: {:error, "Missing or invalid delete_message_seconds"}

  defp audit_headers(reason) when is_binary(reason) and reason != "" do
    [{"X-Audit-Log-Reason", URI.encode(reason)}]
  end

  defp audit_headers(_reason), do: []
end
