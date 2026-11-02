defmodule Lux.Beams.Discord.ModerationBeam do
  @moduledoc """
  An autonomous workflow beam coordinating Discord moderation actions:
  1. Filters message content against prohibited keywords.
  2. If flagged, deletes the infringing message from the channel.
  3. Applies timeout to the offending member.
  4. Publishes a structured moderation audit notice to the log channel.
  """

  use Lux.Beam,
    name: "Discord Moderation Beam",
    description: "Automates content filtering, message deletion, member timeout, and audit log announcement",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild Snowflake ID"},
        channel_id: %{type: :string, description: "Channel where message was sent"},
        message_id: %{type: :string, description: "Offending message ID"},
        user_id: %{type: :string, description: "Offending user ID"},
        content: %{type: :string, description: "Message content to check"},
        prohibited_words: %{type: :array, items: %{type: :string}},
        log_channel_id: %{type: :string, description: "Mod audit channel ID"},
        timeout_seconds: %{type: :integer, description: "Timeout duration in seconds"}
      },
      required: ["guild_id", "channel_id", "message_id", "user_id", "content", "prohibited_words"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        flagged: %{type: :boolean},
        deleted: %{type: :boolean},
        timed_out: %{type: :boolean},
        audit_logged: %{type: :boolean}
      },
      required: ["flagged"]
    }

  alias Lux.Prisms.Discord.{MessageManagementPrism, ModerationPrism}

  @doc """
  Runs the moderation workflow sequence.
  """
  def run(input, context \\ %{}) do
    guild_id = input[:guild_id] || input["guild_id"]
    channel_id = input[:channel_id] || input["channel_id"]
    message_id = input[:message_id] || input["message_id"]
    user_id = input[:user_id] || input["user_id"]
    content = input[:content] || input["content"]
    prohibited = input[:prohibited_words] || input["prohibited_words"] || []
    log_channel_id = input[:log_channel_id] || input["log_channel_id"]
    timeout_secs = input[:timeout_seconds] || input["timeout_seconds"] || 300
    plug = input[:plug] || input["plug"]

    # Step 1: Content filtering
    {:ok, %{result: filter_res}} =
      ModerationPrism.run(%{
        action: "filter_content",
        payload: %{content: content, prohibited_words: prohibited}
      })

    if filter_res.flagged do
      # Step 2: Delete message
      {:ok, _del_res} =
        MessageManagementPrism.run(%{
          action: "delete_message",
          payload: %{channel_id: channel_id, message_id: message_id, plug: plug}
        })

      # Step 3: Timeout member
      {:ok, _timeout_res} =
        ModerationPrism.run(%{
          action: "timeout_member",
          payload: %{guild_id: guild_id, user_id: user_id, duration_seconds: timeout_secs, plug: plug}
        })

      # Step 4: Audit notification (if log_channel_id provided)
      audit_logged =
        if log_channel_id do
          notice_text = "🛡️ **Moderation Intervention**: User <@#{user_id}> timed out for #{timeout_secs}s. Offending message deleted. Flagged terms: #{inspect(filter_res.matches)}"
          case MessageManagementPrism.run(%{
            action: "create_message",
            payload: %{channel_id: log_channel_id, content: notice_text, plug: plug}
          }) do
            {:ok, _} -> true
            _ -> false
          end
        else
          false
        end

      {:ok,
       %{
         flagged: true,
         deleted: true,
         timed_out: true,
         audit_logged: audit_logged
       }}
    else
      {:ok,
       %{
         flagged: false,
         deleted: false,
         timed_out: false,
         audit_logged: false
       }}
    end
  end
end
