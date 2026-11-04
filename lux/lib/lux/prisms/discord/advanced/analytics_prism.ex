defmodule Lux.Prisms.Discord.Advanced.AnalyticsPrism do
  @moduledoc """
  A prism that manages Discord server analytics, event logging, and member usage statistics.
  """

  use Lux.Prism,
    name: "Discord Analytics Prism",
    description: "Tracks server telemetry, logs events, and compiles activity statistics",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["log_event", "server_stats", "member_stats", "reset"],
          default: "server_stats"
        },
        guild_id: %{type: :string},
        user_id: %{type: :string},
        event_type: %{type: :string},
        metadata: %{type: :object}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        guild_id: %{type: :string},
        stats: %{type: [:object, :null]},
        status: %{type: :string}
      },
      required: ["action", "guild_id", "status"]
    }

  alias Lux.Discord.Analytics

  @impl true
  def handler(inputs, _context) do
    action = Map.get(inputs, "action") || Map.get(inputs, :action, "server_stats")
    guild_id = Map.get(inputs, "guild_id") || Map.get(inputs, :guild_id)

    case action do
      "log_event" ->
        event_type = Map.get(inputs, "event_type") || Map.get(inputs, :event_type, "message_sent")
        user_id = Map.get(inputs, "user_id") || Map.get(inputs, :user_id)
        meta = Map.get(inputs, "metadata") || Map.get(inputs, :metadata, %{})

        event = Analytics.log_event(event_type, guild_id, user_id, meta)
        {:ok, %{action: "log_event", guild_id: guild_id, stats: event, status: "logged"}}

      "member_stats" ->
        user_id = Map.get(inputs, "user_id") || Map.get(inputs, :user_id, "default_user")
        stats = Analytics.get_member_stats(guild_id, user_id)
        {:ok, %{action: "member_stats", guild_id: guild_id, stats: stats, status: "ok"}}

      "reset" ->
        Analytics.reset!()
        {:ok, %{action: "reset", guild_id: guild_id, stats: nil, status: "reset"}}

      _server_stats ->
        stats = Analytics.get_server_stats(guild_id)
        {:ok, %{action: "server_stats", guild_id: guild_id, stats: stats, status: "ok"}}
    end
  end
end
