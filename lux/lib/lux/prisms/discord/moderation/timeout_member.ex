defmodule Lux.Prisms.Discord.Moderation.TimeoutMember do
  @moduledoc "A prism for timing out (muting) a member."
  use Lux.Prism,
    name: "Timeout Discord Member",
    description: "Times out a member in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        duration_minutes: %{type: :integer, description: "Timeout in minutes (max 40320)", minimum: 1, maximum: 40320},
        reason: %{type: :string, maxLength: 512}
      },
      required: ["guild_id", "user_id", "duration_minutes"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        timed_out: %{type: :boolean},
        user_id: %{type: :string},
        expires_at: %{type: :string, description: "ISO 8601 expiry"}
      }
    }
  def handler(input, _ctx) do
    expires_at = DateTime.utc_now() |> DateTime.add(input["duration_minutes"] * 60, :second) |> DateTime.to_iso8601()
    body = %{communication_disabled_until: expires_at}
    body = if input["reason"], do: Map.put(body, :reason, input["reason"]), else: body
    case Lux.Integrations.Discord.Client.request(:patch, "/guilds/#{input["guild_id"]}/members/#{input["user_id"]}", json: body) do
      {:ok, _} -> {:ok, %{timed_out: true, user_id: input["user_id"], expires_at: expires_at}}
      {:error, reason} -> {:error, "Timeout failed: #{reason}"}
    end
  end
end
