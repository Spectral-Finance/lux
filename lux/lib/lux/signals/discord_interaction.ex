defmodule Lux.Signals.DiscordInteraction do
  @moduledoc """
  Signal representing a Discord interaction event (slash commands, buttons, modals, select menus).
  Supports bidirectional conversion between raw Discord Gateway/Webhook interactions and typed Lux signals.
  """

  use Lux.Signal,
    schema_id: Lux.Schemas.DiscordInteractionSchema

  @type_names %{
    1 => "ping",
    2 => "application_command",
    3 => "message_component",
    4 => "application_command_autocomplete",
    5 => "modal_submit"
  }

  @doc """
  Parses a raw Discord interaction into a validated `Lux.Signal` struct.
  """
  def from_event(raw) when is_map(raw) do
    type = raw["type"] || raw[:type] || 2
    type_name = Map.get(@type_names, type, "application_command")

    user_raw =
      raw["user"] || raw[:user] ||
      get_in(raw, ["member", "user"]) || get_in(raw, [:member, :user]) || %{}

    user = %{
      "id" => to_string(user_raw["id"] || user_raw[:id] || ""),
      "username" => to_string(user_raw["username"] || user_raw[:username] || "unknown"),
      "discriminator" => to_string(user_raw["discriminator"] || user_raw[:discriminator] || "0"),
      "avatar" => user_raw["avatar"] || user_raw[:avatar]
    }

    data_raw = raw["data"] || raw[:data] || %{}

    payload =
      %{
        "id" => to_string(raw["id"] || raw[:id] || ""),
        "application_id" => to_string(raw["application_id"] || raw[:application_id] || ""),
        "type" => type,
        "type_name" => type_name,
        "data" => data_raw,
        "guild_id" => (raw["guild_id"] || raw[:guild_id]) && to_string(raw["guild_id"] || raw[:guild_id]),
        "channel_id" => (raw["channel_id"] || raw[:channel_id]) && to_string(raw["channel_id"] || raw[:channel_id]),
        "user" => user,
        "token" => to_string(raw["token"] || raw[:token] || ""),
        "version" => raw["version"] || raw[:version] || 1
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    new(%{
      sender: user["username"],
      topic: "discord.interaction.#{payload["id"]}",
      payload: payload,
      metadata: %{
        platform: "discord",
        interaction_type: type_name,
        command_name: data_raw["name"] || data_raw[:name]
      }
    })
  end

  @doc """
  Converts a `Lux.Signal` or payload map back into the raw Discord interaction format.
  """
  def to_event(%Lux.Signal{payload: payload}), do: to_event(payload)
  def to_event(payload) when is_map(payload) do
    %{
      "id" => payload["id"] || payload[:id],
      "application_id" => payload["application_id"] || payload[:application_id],
      "type" => payload["type"] || payload[:type],
      "data" => payload["data"] || payload[:data] || %{},
      "guild_id" => payload["guild_id"] || payload[:guild_id],
      "channel_id" => payload["channel_id"] || payload[:channel_id],
      "user" => payload["user"] || payload[:user],
      "token" => payload["token"] || payload[:token],
      "version" => payload["version"] || payload[:version] || 1
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end
end
