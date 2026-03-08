defmodule Lux.Signals.Discord.PresenceSignal do
  @moduledoc "Discord presence signal: member status, activities, guild presence."

  defstruct [:user_id, :status, :activities, :guild_id, :client_status, :metadata, :timestamp]

  @valid_statuses [:online, :idle, :dnd, :offline, :invisible]

  def new(attrs) when is_map(attrs) do
    status = attrs[:status] || :offline
    if status in @valid_statuses do
      {:ok, %__MODULE__{
        user_id: attrs[:user_id],
        status: status,
        activities: attrs[:activities] || [],
        guild_id: attrs[:guild_id],
        client_status: attrs[:client_status] || %{},
        metadata: attrs[:metadata],
        timestamp: DateTime.utc_now()
      }}
    else
      {:error, :invalid_status}
    end
  end

  def to_discord(%__MODULE__{} = signal) do
    %{
      "user" => %{"id" => signal.user_id},
      "status" => to_string(signal.status),
      "activities" => Enum.map(signal.activities, &activity_to_discord/1),
      "guild_id" => signal.guild_id,
      "client_status" => signal.client_status
    }
  end

  def from_discord(payload) when is_map(payload) do
    new(%{
      user_id: get_in(payload, ["user", "id"]),
      status: String.to_existing_atom(payload["status"] || "offline"),
      activities: Enum.map(payload["activities"] || [], &activity_from_discord/1),
      guild_id: payload["guild_id"],
      client_status: payload["client_status"] || %{}
    })
  end

  def valid_statuses, do: @valid_statuses

  defp activity_to_discord(activity) when is_map(activity), do: activity
  defp activity_to_discord(_), do: %{}

  defp activity_from_discord(a) when is_map(a), do: %{name: a["name"], type: a["type"], state: a["state"]}
  defp activity_from_discord(_), do: %{}
end
