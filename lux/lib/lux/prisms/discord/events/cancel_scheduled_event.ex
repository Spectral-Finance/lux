defmodule Lux.Prisms.Discord.Events.CancelScheduledEvent do
  @moduledoc """
  Cancels a Discord scheduled event by deleting it from the guild.
  """

  use Lux.Prism,
    name: "Cancel Discord Scheduled Event",
    description: "Deletes a guild scheduled event from Discord",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Discord guild ID", pattern: "^[0-9]{17,20}$"},
        event_id: %{
          type: :string,
          description: "Discord scheduled event ID",
          pattern: "^[0-9]{17,20}$"
        },
        reason: %{type: :string, description: "Optional Discord audit log reason"}
      },
      required: ["guild_id", "event_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        cancelled: %{type: :boolean, description: "Whether the event was cancelled"},
        guild_id: %{type: :string, description: "Discord guild ID"},
        event_id: %{type: :string, description: "Discord scheduled event ID"}
      },
      required: ["cancelled"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(params, _agent) do
    with {:ok, guild_id} <- validate_string(params, :guild_id),
         {:ok, event_id} <- validate_string(params, :event_id) do
      opts = %{headers: audit_headers(params[:reason])}

      case Client.request(:delete, "/guilds/#{guild_id}/scheduled-events/#{event_id}", opts) do
        {:ok, _response} -> {:ok, %{cancelled: true, guild_id: guild_id, event_id: event_id}}
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
