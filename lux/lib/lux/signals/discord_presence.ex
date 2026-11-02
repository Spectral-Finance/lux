defmodule Lux.Signals.DiscordPresence do
  @moduledoc """
  Signal representing a Discord presence update event (user status, active games, platforms).
  Supports bidirectional conversion between raw Discord Gateway presence events and typed Lux signals.
  """

  use Lux.Signal,
    schema_id: Lux.Schemas.DiscordPresenceSchema

  @doc """
  Parses a raw Discord presence update into a validated `Lux.Signal` struct.
  """
  def from_event(raw) when is_map(raw) do
    user_raw = raw["user"] || raw[:user] || %{}
    user_id = to_string(user_raw["id"] || user_raw[:id] || raw["user_id"] || raw[:user_id] || "")

    status = to_string(raw["status"] || raw[:status] || "offline")

    activities =
      Enum.map(raw["activities"] || raw[:activities] || [], fn act ->
        %{
          "name" => to_string(act["name"] || act[:name] || ""),
          "type" => act["type"] || act[:type] || 0,
          "state" => act["state"] || act[:state],
          "details" => act["details"] || act[:details],
          "url" => act["url"] || act[:url]
        }
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()
      end)

    client_status =
      case raw["client_status"] || raw[:client_status] do
        cs when is_map(cs) ->
          %{
            "desktop" => cs["desktop"] || cs[:desktop],
            "mobile" => cs["mobile"] || cs[:mobile],
            "web" => cs["web"] || cs[:web]
          }
          |> Enum.reject(fn {_, v} -> is_nil(v) end)
          |> Map.new()

        _ ->
          %{}
      end

    guild_id = (raw["guild_id"] || raw[:guild_id]) && to_string(raw["guild_id"] || raw[:guild_id])

    payload =
      %{
        "user_id" => user_id,
        "guild_id" => guild_id,
        "status" => status,
        "activities" => activities,
        "client_status" => client_status
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    new(%{
      sender: user_id,
      topic: "discord.presence.#{user_id}",
      payload: payload,
      metadata: %{
        platform: "discord",
        event_type: "PRESENCE_UPDATE",
        guild_id: guild_id
      }
    })
  end

  @doc """
  Converts a `Lux.Signal` or payload map back into the raw Discord presence format.
  """
  def to_event(%Lux.Signal{payload: payload}), do: to_event(payload)
  def to_event(payload) when is_map(payload) do
    %{
      "user" => %{"id" => payload["user_id"] || payload[:user_id]},
      "guild_id" => payload["guild_id"] || payload[:guild_id],
      "status" => payload["status"] || payload[:status],
      "activities" => payload["activities"] || payload[:activities] || [],
      "client_status" => payload["client_status"] || payload[:client_status] || %{}
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end
end
