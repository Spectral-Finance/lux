defmodule Lux.Prisms.Discord.ModerationPrism do
  use Lux.Prism,
    name: "Discord Moderation",
    description: "Moderate Discord server members (timeout, kick, ban)",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["timeout", "kick", "ban"]},
        guild_id: %{type: :string},
        user_id: %{type: :string},
        duration_seconds: %{type: :integer},
        delete_message_seconds: %{type: :integer}
      },
      required: ["action", "guild_id", "user_id"]
    }

  alias Lux.Utils.DiscordApi

  def handler(%{"action" => "timeout", "guild_id" => guild_id, "user_id" => user_id, "duration_seconds" => duration_seconds}, _ctx) do
    # Calculate the ISO8601 timestamp for timeout
    timeout_until = DateTime.utc_now() |> DateTime.add(duration_seconds, :second) |> DateTime.to_iso8601()
    DiscordApi.request(:patch, "/guilds/#{guild_id}/members/#{user_id}", %{communication_disabled_until: timeout_until})
  end

  def handler(%{"action" => "timeout"}, _ctx), do: {:error, "guild_id, user_id, and duration_seconds are required for timeout"}

  def handler(%{"action" => "kick", "guild_id" => guild_id, "user_id" => user_id}, _ctx) do
    DiscordApi.request(:delete, "/guilds/#{guild_id}/members/#{user_id}")
  end

  def handler(%{"action" => "kick"}, _ctx), do: {:error, "guild_id and user_id are required for kick"}

  def handler(%{"action" => "ban", "guild_id" => guild_id, "user_id" => user_id} = input, _ctx) do
    payload = %{}
    payload = if sec = Map.get(input, "delete_message_seconds"), do: Map.put(payload, :delete_message_seconds, sec), else: payload
    DiscordApi.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", payload)
  end

  def handler(%{"action" => "ban"}, _ctx), do: {:error, "guild_id and user_id are required for ban"}

  def handler(_, _), do: {:error, "Invalid action or missing required parameters"}
end
