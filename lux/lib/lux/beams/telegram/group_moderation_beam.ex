defmodule Lux.Beams.Telegram.GroupModerationBeam do
  @moduledoc """
  A beam pipeline for automated Telegram group moderation:
  1. Inspects incoming message for spam, unauthorized links, banned words, and mass mentions
  2. Executes moderation enforcement (delete, mute, ban, warn)
  3. Records audit log entry with formatted admin notifications
  """

  use Lux.Beam,
    name: "Telegram Group Moderation Pipeline",
    description: "Orchestrates Telegram group content scanning, action enforcement, and audit logging",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{type: :object, description: "Raw Telegram message payload"},
        chat_id: %{type: [:string, :integer], description: "Target chat identifier"},
        execute_action: %{type: :boolean, description: "Whether to execute action immediately"}
      },
      required: ["message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        moderation: %{type: :object},
        audit_log: %{type: :object}
      },
      required: ["moderation"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Telegram.GroupManagement.ModerateContent
  alias Lux.Prisms.Telegram.GroupManagement.LogAdminAction

  sequence do
    # 1. Scan and moderate message
    step(:moderation, ModerateContent, %{
      message: [:input, :message],
      execute_action: [:input, :execute_action]
    })

    # 2. Record audit log
    step(:audit_log, LogAdminAction, %{
      action: [:steps, :moderation, :result, :action],
      chat_id: [:input, :chat_id],
      reason: "Automated group moderation"
    })
  end

  @doc """
  Direct execution helper for moderating a Telegram group message.
  """
  def moderate_message(chat_id, message, opts \\ []) do
    execute = Keyword.get(opts, :execute_action, true)
    config = Keyword.get(opts, :config, %{})
    plug = Keyword.get(opts, :plug)

    params = %{
      message: message,
      config: config,
      execute_action: execute,
      plug: plug
    }

    with {:ok, mod_result} <- ModerateContent.handler(params, %{}) do
      user_id = get_in(message, [:from, :id]) || get_in(message, ["from", "id"]) || Map.get(message, :user_id)

      log_params = %{
        action: mod_result.action,
        chat_id: chat_id,
        target_id: user_id,
        reason: "Content violation: #{mod_result.violation || "none"}"
      }

      {:ok, log_result} = LogAdminAction.handler(log_params, %{})

      {:ok,
       %{
         moderation: mod_result,
         audit_log: log_result
       }}
    end
  end
end
