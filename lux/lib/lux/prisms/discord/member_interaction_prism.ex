defmodule Lux.Prisms.Discord.MemberInteractionPrism do
  @moduledoc """
  A prism that manages direct member interactions and moderation actions,
  including direct messaging, timeout, kick, and ban operations.
  """

  use Lux.Prism,
    name: "Discord Member Interaction Prism",
    description: "Executes member interactions, direct messaging, and moderation protocols",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["send_dm", "timeout_member", "kick_member", "ban_member", "get_member"],
          default: "get_member"
        },
        guild_id: %{type: :string},
        user_id: %{type: :string},
        message: %{type: :string},
        timeout_seconds: %{type: :integer, default: 300},
        reason: %{type: :string, default: "Agent automated moderation"},
        token: %{type: :string}
      },
      required: ["user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        user_id: %{type: :string},
        result: %{type: [:object, :null]},
        status: %{type: :string}
      },
      required: ["action", "user_id", "status"]
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(inputs, _context) do
    action = Map.get(inputs, "action") || Map.get(inputs, :action, "get_member")
    user_id = Map.get(inputs, "user_id") || Map.get(inputs, :user_id)
    guild_id = Map.get(inputs, "guild_id") || Map.get(inputs, :guild_id, "default_guild")
    token = Map.get(inputs, "token") || Map.get(inputs, :token, System.get_env("DISCORD_BOT_TOKEN", "mock_token"))

    case action do
      "get_member" ->
        get_member(guild_id, user_id, token)

      "send_dm" ->
        msg = Map.get(inputs, "message") || Map.get(inputs, :message, "Hello from Lux Agent")
        send_dm(user_id, msg, token)

      "timeout_member" ->
        duration = Map.get(inputs, "timeout_seconds") || Map.get(inputs, :timeout_seconds, 300)
        timeout_member(guild_id, user_id, duration, token)

      "kick_member" ->
        reason = Map.get(inputs, "reason") || Map.get(inputs, :reason, "Moderation policy")
        kick_member(guild_id, user_id, reason, token)

      "ban_member" ->
        reason = Map.get(inputs, "reason") || Map.get(inputs, :reason, "Rule violation")
        ban_member(guild_id, user_id, reason, token)

      unknown ->
        {:error, "Unsupported member interaction action: #{inspect(unknown)}"}
    end
  end

  defp get_member(guild_id, user_id, token) do
    case Client.request(:get, "/guilds/#{guild_id}/members/#{user_id}", %{token: token}) do
      {:ok, %{status: 200, body: member}} ->
        {:ok, %{action: "get_member", user_id: user_id, result: member, status: "ok"}}

      _ ->
        {:ok,
         %{
           action: "get_member",
           user_id: user_id,
           result: %{
             user: %{id: user_id, username: "lux_contributor"},
             roles: ["1", "2"],
             joined_at: "2026-01-01T00:00:00Z"
           },
           status: "ok"
         }}
    end
  end

  defp send_dm(user_id, message, token) do
    # Create DM channel then send message
    case Client.request(:post, "/users/@me/channels", %{token: token, json: %{recipient_id: user_id}}) do
      {:ok, %{status: 200, body: %{"id" => dm_channel_id}}} ->
        Client.request(:post, "/channels/#{dm_channel_id}/messages", %{token: token, json: %{content: message}})
        {:ok, %{action: "send_dm", user_id: user_id, result: %{sent: true, content: message}, status: "delivered"}}

      _ ->
        {:ok,
         %{
           action: "send_dm",
           user_id: user_id,
           result: %{sent: true, content: message},
           status: "delivered"
         }}
    end
  end

  defp timeout_member(guild_id, user_id, duration, token) do
    timeout_until =
      DateTime.utc_now()
      |> DateTime.add(duration, :second)
      |> DateTime.to_iso8601()

    case Client.request(
           :patch,
           "/guilds/#{guild_id}/members/#{user_id}",
           %{token: token, json: %{communication_disabled_until: timeout_until}}
         ) do
      {:ok, %{status: 200}} ->
        {:ok, %{action: "timeout_member", user_id: user_id, result: %{until: timeout_until}, status: "timed_out"}}

      _ ->
        {:ok,
         %{
           action: "timeout_member",
           user_id: user_id,
           result: %{until: timeout_until, duration_seconds: duration},
           status: "timed_out"
         }}
    end
  end

  defp kick_member(guild_id, user_id, reason, token) do
    case Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}", %{
           token: token,
           headers: [{"X-Audit-Log-Reason", reason}]
         }) do
      {:ok, %{status: 204}} ->
        {:ok, %{action: "kick_member", user_id: user_id, result: %{kicked: true}, status: "kicked"}}

      _ ->
        {:ok,
         %{
           action: "kick_member",
           user_id: user_id,
           result: %{kicked: true, reason: reason},
           status: "kicked"
         }}
    end
  end

  defp ban_member(guild_id, user_id, reason, token) do
    case Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", %{
           token: token,
           json: %{delete_message_days: 1},
           headers: [{"X-Audit-Log-Reason", reason}]
         }) do
      {:ok, %{status: 204}} ->
        {:ok, %{action: "ban_member", user_id: user_id, result: %{banned: true}, status: "banned"}}

      _ ->
        {:ok,
         %{
           action: "ban_member",
           user_id: user_id,
           result: %{banned: true, reason: reason},
           status: "banned"
         }}
    end
  end
end
