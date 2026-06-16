defmodule Lux.Prisms.Discord.Moderation.RemoveTimeout do
  @moduledoc """
  Removes a Discord communication timeout from a guild member.
  """

  use Lux.Prism,
    name: "Remove Discord Member Timeout",
    description: "Clears communication_disabled_until for a Discord guild member",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Discord guild ID", pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, description: "Discord user ID", pattern: "^[0-9]{17,20}$"},
        reason: %{type: :string, description: "Optional Discord audit log reason"}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        timeout_removed: %{type: :boolean, description: "Whether the timeout was removed"},
        guild_id: %{type: :string, description: "Discord guild ID"},
        user_id: %{type: :string, description: "Discord user ID"}
      },
      required: ["timeout_removed"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(params, _agent) do
    with {:ok, guild_id} <- validate_string(params, :guild_id),
         {:ok, user_id} <- validate_string(params, :user_id) do
      opts = %{
        json: %{communication_disabled_until: nil},
        headers: audit_headers(params[:reason])
      }

      case Client.request(:patch, "/guilds/#{guild_id}/members/#{user_id}", opts) do
        {:ok, _member} -> {:ok, %{timeout_removed: true, guild_id: guild_id, user_id: user_id}}
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

  defp audit_headers(reason) when is_binary(reason) and reason != "" do
    [{"X-Audit-Log-Reason", URI.encode(reason)}]
  end

  defp audit_headers(_reason), do: []
end
