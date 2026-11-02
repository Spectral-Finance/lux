defmodule Lux.Prisms.Discord.ModerationPrism do
  @moduledoc """
  Core Prism for Discord server moderation tasks:
  - User timeout management (muting and un-muting members)
  - Member bans and unbans
  - Automated content filtering and keyword rule checking
  - Audit logging for moderation events
  """

  use Lux.Prism,
    name: "Discord Moderation Prism",
    description: "Executes server moderation tasks including user timeouts, bans, unbans, content filtering, and audit logging",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "timeout_member",
            "remove_timeout",
            "ban_member",
            "unban_member",
            "filter_content",
            "audit_action"
          ],
          description: "Moderation action to perform"
        },
        payload: %{
          type: :object,
          description: "Action-specific parameters and options"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: :object}
      },
      required: ["action", "result"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action", "filter_content")
    payload = Map.get(input, :payload) || Map.get(input, "payload", %{})

    case execute_action(action, payload) do
      {:ok, result} ->
        {:ok, %{action: action, result: result}}

      {:error, reason} ->
        {:error, "ModerationPrism error on '#{action}': #{inspect(reason)}"}
    end
  end

  defp execute_action("timeout_member", payload) do
    guild_id = Map.get(payload, :guild_id, Map.get(payload, "guild_id"))
    user_id = Map.get(payload, :user_id, Map.get(payload, "user_id"))
    duration_sec = Map.get(payload, :duration_seconds, Map.get(payload, "duration_seconds", 300))
    opts = extract_client_opts(payload)

    # Compute future ISO8601 timestamp
    future_time =
      DateTime.utc_now()
      |> DateTime.add(duration_sec, :second)
      |> DateTime.to_iso8601()

    body = %{"communication_disabled_until" => future_time}

    case Client.request(:patch, "/guilds/#{guild_id}/members/#{user_id}", Map.put(opts, :json, body)) do
      {:ok, res} ->
        {:ok,
         %{
           timed_out: true,
           user_id: user_id,
           until: future_time,
           raw: res
         }}

      error ->
        error
    end
  end

  defp execute_action("remove_timeout", payload) do
    guild_id = Map.get(payload, :guild_id, Map.get(payload, "guild_id"))
    user_id = Map.get(payload, :user_id, Map.get(payload, "user_id"))
    opts = extract_client_opts(payload)

    body = %{"communication_disabled_until" => nil}

    case Client.request(:patch, "/guilds/#{guild_id}/members/#{user_id}", Map.put(opts, :json, body)) do
      {:ok, _} -> {:ok, %{timeout_removed: true, user_id: user_id}}
      error -> error
    end
  end

  defp execute_action("ban_member", payload) do
    guild_id = Map.get(payload, :guild_id, Map.get(payload, "guild_id"))
    user_id = Map.get(payload, :user_id, Map.get(payload, "user_id"))
    delete_secs = Map.get(payload, :delete_message_seconds, Map.get(payload, "delete_message_seconds", 86_400))
    opts = extract_client_opts(payload)

    body = %{"delete_message_seconds" => delete_secs}

    case Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", Map.put(opts, :json, body)) do
      {:ok, _} -> {:ok, %{banned: true, user_id: user_id}}
      error -> error
    end
  end

  defp execute_action("unban_member", payload) do
    guild_id = Map.get(payload, :guild_id, Map.get(payload, "guild_id"))
    user_id = Map.get(payload, :user_id, Map.get(payload, "user_id"))
    opts = extract_client_opts(payload)

    case Client.request(:delete, "/guilds/#{guild_id}/bans/#{user_id}", opts) do
      {:ok, _} -> {:ok, %{unbanned: true, user_id: user_id}}
      error -> error
    end
  end

  defp execute_action("filter_content", payload) do
    content = Map.get(payload, :content, Map.get(payload, "content", ""))
    prohibited = Map.get(payload, :prohibited_words, Map.get(payload, "prohibited_words", []))

    downcased = String.downcase(content)
    matches = Enum.filter(prohibited, fn word -> String.contains?(downcased, String.downcase(word)) end)

    {:ok,
     %{
       flagged: length(matches) > 0,
       matches: matches,
       content_length: String.length(content)
     }}
  end

  defp execute_action("audit_action", payload) do
    action_type = Map.get(payload, :type, "moderator_intervention")
    target_id = Map.get(payload, :target_id, "unknown")
    reason = Map.get(payload, :reason, "Policy violation")
    moderator = Map.get(payload, :moderator, "LuxAutonomousAgent")

    log_entry = %{
      audit_id: "audit_#{:os.system_time(:millisecond)}",
      type: action_type,
      target_id: target_id,
      reason: reason,
      moderator: moderator,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {:ok, log_entry}
  end

  defp execute_action(unknown, _payload) do
    {:error, "Unknown action: #{unknown}"}
  end

  defp extract_client_opts(payload) do
    opts = %{}

    opts =
      case Map.get(payload, :token, Map.get(payload, "token")) do
        nil -> opts
        token -> Map.put(opts, :token, token)
      end

    case Map.get(payload, :plug, Map.get(payload, "plug")) do
      nil -> opts
      plug -> Map.put(opts, :plug, plug)
    end
  end
end
