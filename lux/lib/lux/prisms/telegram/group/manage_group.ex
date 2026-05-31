defmodule Lux.Prisms.Telegram.Group.ManageGroup do
  @moduledoc """
  A prism for planning and executing Telegram group/channel administration.

  The prism exposes member management, permission updates, moderation, spam
  protection, group settings, channel posts, and admin audit logging through one
  normalized action surface.
  """

  @action_values ~w(
    ban_member
    unban_member
    restrict_member
    promote_member
    demote_member
    set_admin_title
    set_member_tag
    ban_sender_chat
    unban_sender_chat
    get_member
    get_admins
    get_member_count
    set_permissions
    set_title
    set_description
    delete_photo
    set_slow_mode
    create_invite_link
    edit_invite_link
    revoke_invite_link
    approve_join_request
    decline_join_request
    pin_message
    unpin_message
    unpin_all_messages
    set_sticker_set
    delete_sticker_set
    create_forum_topic
    edit_forum_topic
    close_forum_topic
    reopen_forum_topic
    delete_forum_topic
    unpin_all_forum_topic_messages
    edit_general_forum_topic
    close_general_forum_topic
    reopen_general_forum_topic
    hide_general_forum_topic
    unhide_general_forum_topic
    unpin_all_general_forum_topic_messages
    send_channel_post
    edit_channel_post
    edit_channel_caption
    delete_channel_post
    delete_messages
    forward_channel_post
    copy_channel_post
    moderate_message
    log_admin_action
  )

  use Lux.Prism,
    name: "Manage Telegram Group",
    description:
      "Plans or executes Telegram group and channel administration actions with moderation and audit logging support",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Telegram group management action to plan or execute",
          enum: @action_values
        },
        execute: %{
          type: :boolean,
          description:
            "When true, executes planned Telegram Bot API requests through Lux.Integrations.Telegram.Client"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Target group, supergroup, or channel id/username"
        },
        from_chat_id: %{
          type: [:string, :integer],
          description: "Source chat id/username for forwarding or copying channel posts"
        },
        user_id: %{
          type: :integer,
          description: "Target Telegram user id for member-management actions"
        },
        sender_chat_id: %{
          type: :integer,
          description: "Target sender chat id for sender-chat ban and unban actions"
        },
        message_id: %{
          type: :integer,
          description: "Target message id for moderation, pinning, editing, or channel posts"
        },
        message_ids: %{
          type: :array,
          description: "Message ids for bulk deleteMessages moderation"
        },
        message_thread_id: %{
          type: :integer,
          description: "Target forum topic message thread id"
        },
        text: %{
          type: :string,
          description: "Message text or content to evaluate for moderation"
        },
        name: %{
          type: :string,
          description: "Invite link name or forum topic name"
        },
        icon_color: %{
          type: :integer,
          description: "Forum topic icon RGB color accepted by Telegram"
        },
        icon_custom_emoji_id: %{
          type: :string,
          description: "Custom emoji id used for a forum topic icon"
        },
        caption: %{
          type: :string,
          description: "Channel post caption for edit/copy operations"
        },
        tag: %{
          type: :string,
          description: "Optional member tag for set_member_tag"
        },
        permissions: %{
          type: :object,
          description: "Telegram ChatPermissions flags"
        },
        permission_template: %{
          type: :string,
          description: "Named permission template",
          enum: ["standard", "media_limited", "read_only", "announcement", "no_links"]
        },
        admin_rights: %{
          type: :object,
          description: "Telegram administrator rights flags"
        },
        admin_template: %{
          type: :string,
          description: "Named administrator rights template",
          enum: ["none", "moderator", "publisher", "community_manager"]
        },
        policy: %{
          type: :object,
          description:
            "Content moderation policy, including optional rate/window thresholds for recent_messages"
        },
        recent_messages: %{
          type: :array,
          description:
            "Optional caller-supplied spam history for the same chat/user, with text and optional age_seconds"
        },
        recent_message_count: %{
          type: :integer,
          description: "Optional precomputed message count for rate-limit moderation checks"
        },
        bot_admin_rights: %{
          type: :object,
          description:
            "Optional map of the bot's Telegram administrator rights used for dry-run preflight"
        },
        log_chat_id: %{
          type: [:string, :integer],
          description: "Optional chat/channel id that receives admin audit log messages"
        },
        token: %{
          type: :string,
          description:
            "Optional Telegram bot token used to authenticate execution. When omitted, the " <>
              "configured Lux.Integrations.Telegram.Client credentials are used instead."
        },
        allow_unverified_admin_rights: %{
          type: :boolean,
          description:
            "When true, permits executing destructive actions (ban/restrict/promote/delete) " <>
              "without verified bot_admin_rights, bypassing the admin-rights safety gate"
        },
        plug: %{
          type: :object,
          description: "Optional Req.Test plug configuration for local tests"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Normalized Telegram group action"
        },
        category: %{
          type: :string,
          description: "Management category for the action"
        },
        planned: %{
          type: :boolean,
          description: "Whether the action was planned successfully"
        },
        executed: %{
          type: :boolean,
          description: "Whether the planned requests were executed"
        },
        request_count: %{
          type: :integer,
          description: "Number of Telegram Bot API requests in the plan"
        },
        requests: %{
          type: :array,
          description: "Planned Telegram Bot API request maps"
        },
        status: %{
          type: :string,
          description: "Moderation outcome for moderate_message plans (clean or flagged)"
        },
        severity: %{
          type: :string,
          description: "Highest moderation violation severity (none, low, medium, or high)"
        },
        moderation_action: %{
          type: :string,
          description: "Resolved moderation action for moderate_message plans"
        },
        violations: %{
          type: :array,
          description: "Normalized moderation violations detected in the evaluated content"
        },
        preflight: %{
          type: :object,
          description:
            "Admin-rights preflight summary, including required_rights, configured, destructive, " <>
              "verified, ok, and missing_rights"
        },
        warnings: %{
          type: :array,
          description:
            "Human-readable safety warnings, e.g. unverified destructive rights or sticker-set " <>
              "capability caveats"
        },
        results: %{
          type: :array,
          description: "Per-request execution results returned when execute is true"
        },
        audit_entry: %{
          type: :object,
          description: "Normalized admin audit entry for the action"
        }
      },
      required: ["action", "planned", "executed", "request_count"]
    }

  alias Lux.Integrations.Telegram.GroupManager
  require Logger

  @doc """
  Plans a Telegram group management action and optionally executes it.
  """
  def handler(params, agent) do
    with {:ok, action} <- fetch_action(params),
         {:ok, plan} <- GroupManager.plan(action, params) do
      agent_name = value(agent, :name, "Unknown Agent")
      Logger.info("Agent #{agent_name} planned Telegram group action #{plan.action}")

      if truthy?(value(params, :execute, false)) do
        execute_plan(plan, params)
      else
        {:ok,
         plan
         |> Map.put(:planned, true)
         |> Map.put(:executed, false)
         |> normalize_output()}
      end
    end
  end

  defp execute_plan(plan, params) do
    execute_opts = take_params(params, [:plug, :token, :allow_unverified_admin_rights])

    case GroupManager.execute(plan, execute_opts) do
      {:ok, executed_plan} ->
        {:ok,
         executed_plan
         |> Map.put(:planned, true)
         |> Map.put(:executed, true)
         |> normalize_output()}

      {:error, %{results: results}} ->
        {:error, "Failed to execute Telegram group action: #{inspect(results)}"}
    end
  end

  defp normalize_output(plan) do
    plan
    |> stringify_fields([:action, :category, :status, :severity, :moderation_action])
    |> Map.update(:requests, [], &Enum.map(&1, fn request -> normalize_request(request) end))
    |> Map.update(:audit_entry, %{}, &normalize_audit_entry/1)
    |> Map.update(:preflight, %{}, &normalize_preflight/1)
    |> Map.update(
      :violations,
      [],
      &Enum.map(&1, fn violation -> normalize_violation(violation) end)
    )
    |> Map.update(:results, [], &Enum.map(&1, fn result -> normalize_result(result) end))
  end

  defp normalize_request(request) do
    stringify_fields(request, [:method, :category, :action])
  end

  defp normalize_audit_entry(audit_entry) do
    stringify_fields(audit_entry, [:category, :status])
  end

  defp normalize_preflight(preflight) do
    preflight
    |> stringify_fields([:action])
    |> stringify_atom_list(:required_rights)
    |> stringify_atom_list(:missing_rights)
  end

  defp normalize_violation(violation) do
    stringify_fields(violation, [:type, :severity])
  end

  defp normalize_result(%{request: request} = result) do
    Map.put(result, :request, normalize_request(request))
  end

  defp normalize_result(result), do: result

  defp stringify_fields(map, fields) when is_map(map) do
    Enum.reduce(fields, map, fn field, acc ->
      if Map.has_key?(acc, field) do
        Map.update!(acc, field, &stringify_atom/1)
      else
        acc
      end
    end)
  end

  defp stringify_fields(value, _fields), do: value

  defp stringify_atom_list(map, field) when is_map(map) do
    if Map.has_key?(map, field) do
      Map.update!(map, field, fn values ->
        Enum.map(values, &stringify_atom/1)
      end)
    else
      map
    end
  end

  defp stringify_atom_list(value, _field), do: value

  defp stringify_atom(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_atom(value), do: value

  defp fetch_action(params) do
    case value(params, :action) do
      action when is_binary(action) -> {:ok, action}
      action when is_atom(action) and not is_nil(action) -> {:ok, action}
      _ -> {:error, "Missing or invalid action"}
    end
  end

  defp take_params(params, keys) do
    Enum.reduce(keys, %{}, fn key, acc ->
      case fetch_value(params, key) do
        {:ok, nil} -> acc
        {:ok, value} -> Map.put(acc, key, value)
        :error -> acc
      end
    end)
  end

  defp fetch_value(params, key) when is_map(params) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(params, key) -> {:ok, Map.get(params, key)}
      Map.has_key?(params, string_key) -> {:ok, Map.get(params, string_key)}
      true -> :error
    end
  end

  defp fetch_value(_params, _key), do: :error

  defp value(params, key, default \\ nil) do
    case fetch_value(params, key) do
      {:ok, value} -> value
      :error -> default
    end
  end

  defp truthy?(value), do: value in [true, "true", 1, "1"]
end
