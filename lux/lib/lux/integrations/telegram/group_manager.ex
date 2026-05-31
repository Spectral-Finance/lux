defmodule Lux.Integrations.Telegram.GroupManager do
  @moduledoc """
  Request planner and executor for Telegram group and channel administration.

  The module keeps moderation, permission, member, settings, channel post, and
  audit-log workflows deterministic. `plan/2` returns Bot API request payloads
  that can be inspected or executed later through `execute/2`.
  """

  alias Lux.Integrations.Telegram.Client

  @permission_keys [
    :can_send_messages,
    :can_send_audios,
    :can_send_documents,
    :can_send_photos,
    :can_send_videos,
    :can_send_video_notes,
    :can_send_voice_notes,
    :can_send_polls,
    :can_send_other_messages,
    :can_add_web_page_previews,
    :can_react_to_messages,
    :can_edit_tag,
    :can_change_info,
    :can_invite_users,
    :can_pin_messages,
    :can_manage_topics
  ]

  @admin_permission_keys [
    :is_anonymous,
    :can_manage_chat,
    :can_delete_messages,
    :can_manage_video_chats,
    :can_restrict_members,
    :can_promote_members,
    :can_change_info,
    :can_invite_users,
    :can_post_stories,
    :can_edit_stories,
    :can_delete_stories,
    :can_post_messages,
    :can_edit_messages,
    :can_pin_messages,
    :can_manage_topics,
    :can_manage_direct_messages,
    :can_manage_tags
  ]

  @actions [
    :ban_member,
    :unban_member,
    :restrict_member,
    :promote_member,
    :demote_member,
    :set_admin_title,
    :set_member_tag,
    :ban_sender_chat,
    :unban_sender_chat,
    :get_member,
    :get_admins,
    :get_member_count,
    :set_permissions,
    :set_title,
    :set_description,
    :delete_photo,
    :set_slow_mode,
    :create_invite_link,
    :edit_invite_link,
    :revoke_invite_link,
    :approve_join_request,
    :decline_join_request,
    :pin_message,
    :unpin_message,
    :unpin_all_messages,
    :set_sticker_set,
    :delete_sticker_set,
    :create_forum_topic,
    :edit_forum_topic,
    :close_forum_topic,
    :reopen_forum_topic,
    :delete_forum_topic,
    :unpin_all_forum_topic_messages,
    :edit_general_forum_topic,
    :close_general_forum_topic,
    :reopen_general_forum_topic,
    :hide_general_forum_topic,
    :unhide_general_forum_topic,
    :unpin_all_general_forum_topic_messages,
    :send_channel_post,
    :edit_channel_post,
    :edit_channel_caption,
    :delete_channel_post,
    :delete_messages,
    :forward_channel_post,
    :copy_channel_post,
    :moderate_message,
    :log_admin_action
  ]

  @action_aliases Map.new(@actions, fn action -> {Atom.to_string(action), action} end)

  @api_specs %{
    ban_member: %{
      category: :member_management,
      path: "/banChatMember",
      required: [:chat_id, :user_id],
      optional: [:until_date, :revoke_messages]
    },
    unban_member: %{
      category: :member_management,
      path: "/unbanChatMember",
      required: [:chat_id, :user_id],
      optional: [:only_if_banned]
    },
    restrict_member: %{
      category: :member_management,
      path: "/restrictChatMember",
      required: [:chat_id, :user_id],
      optional: [:until_date, :use_independent_chat_permissions],
      permissions: :member,
      default_permission_template: :read_only
    },
    promote_member: %{
      category: :member_management,
      path: "/promoteChatMember",
      required: [:chat_id, :user_id],
      optional: [],
      admin_rights: true,
      default_admin_template: :moderator
    },
    demote_member: %{
      category: :member_management,
      path: "/promoteChatMember",
      required: [:chat_id, :user_id],
      optional: [],
      admin_rights: true,
      default_admin_template: :none
    },
    set_admin_title: %{
      category: :member_management,
      path: "/setChatAdministratorCustomTitle",
      required: [:chat_id, :user_id, :custom_title],
      optional: []
    },
    set_member_tag: %{
      category: :member_management,
      path: "/setChatMemberTag",
      required: [:chat_id, :user_id],
      optional: [:tag]
    },
    ban_sender_chat: %{
      category: :member_management,
      path: "/banChatSenderChat",
      required: [:chat_id, :sender_chat_id],
      optional: []
    },
    unban_sender_chat: %{
      category: :member_management,
      path: "/unbanChatSenderChat",
      required: [:chat_id, :sender_chat_id],
      optional: []
    },
    get_member: %{
      category: :member_management,
      path: "/getChatMember",
      required: [:chat_id, :user_id],
      optional: []
    },
    get_admins: %{
      category: :member_management,
      path: "/getChatAdministrators",
      required: [:chat_id],
      optional: [:return_bots]
    },
    get_member_count: %{
      category: :member_management,
      path: "/getChatMemberCount",
      required: [:chat_id],
      optional: []
    },
    set_permissions: %{
      category: :permission_management,
      path: "/setChatPermissions",
      required: [:chat_id],
      optional: [:use_independent_chat_permissions],
      permissions: :chat,
      default_permission_template: :standard
    },
    set_title: %{
      category: :group_settings,
      path: "/setChatTitle",
      required: [:chat_id, :title],
      optional: []
    },
    set_description: %{
      category: :group_settings,
      path: "/setChatDescription",
      required: [:chat_id, :description],
      optional: []
    },
    delete_photo: %{
      category: :group_settings,
      path: "/deleteChatPhoto",
      required: [:chat_id],
      optional: []
    },
    set_slow_mode: %{
      category: :spam_protection,
      path: "/setChatSlowModeDelay",
      required: [:chat_id, :slow_mode_delay],
      optional: []
    },
    create_invite_link: %{
      category: :group_settings,
      path: "/createChatInviteLink",
      required: [:chat_id],
      optional: [:name, :expire_date, :member_limit, :creates_join_request]
    },
    edit_invite_link: %{
      category: :group_settings,
      path: "/editChatInviteLink",
      required: [:chat_id, :invite_link],
      optional: [:name, :expire_date, :member_limit, :creates_join_request]
    },
    revoke_invite_link: %{
      category: :group_settings,
      path: "/revokeChatInviteLink",
      required: [:chat_id, :invite_link],
      optional: []
    },
    approve_join_request: %{
      category: :member_management,
      path: "/approveChatJoinRequest",
      required: [:chat_id, :user_id],
      optional: []
    },
    decline_join_request: %{
      category: :member_management,
      path: "/declineChatJoinRequest",
      required: [:chat_id, :user_id],
      optional: []
    },
    pin_message: %{
      category: :group_settings,
      path: "/pinChatMessage",
      required: [:chat_id, :message_id],
      optional: [:disable_notification]
    },
    unpin_message: %{
      category: :group_settings,
      path: "/unpinChatMessage",
      required: [:chat_id],
      optional: [:message_id]
    },
    unpin_all_messages: %{
      category: :group_settings,
      path: "/unpinAllChatMessages",
      required: [:chat_id],
      optional: []
    },
    set_sticker_set: %{
      category: :group_settings,
      path: "/setChatStickerSet",
      required: [:chat_id, :sticker_set_name],
      optional: []
    },
    delete_sticker_set: %{
      category: :group_settings,
      path: "/deleteChatStickerSet",
      required: [:chat_id],
      optional: []
    },
    create_forum_topic: %{
      category: :group_settings,
      path: "/createForumTopic",
      required: [:chat_id, :name],
      optional: [:icon_color, :icon_custom_emoji_id]
    },
    edit_forum_topic: %{
      category: :group_settings,
      path: "/editForumTopic",
      required: [:chat_id, :message_thread_id],
      optional: [:name, :icon_custom_emoji_id]
    },
    close_forum_topic: %{
      category: :group_settings,
      path: "/closeForumTopic",
      required: [:chat_id, :message_thread_id],
      optional: []
    },
    reopen_forum_topic: %{
      category: :group_settings,
      path: "/reopenForumTopic",
      required: [:chat_id, :message_thread_id],
      optional: []
    },
    delete_forum_topic: %{
      category: :group_settings,
      path: "/deleteForumTopic",
      required: [:chat_id, :message_thread_id],
      optional: []
    },
    unpin_all_forum_topic_messages: %{
      category: :group_settings,
      path: "/unpinAllForumTopicMessages",
      required: [:chat_id, :message_thread_id],
      optional: []
    },
    edit_general_forum_topic: %{
      category: :group_settings,
      path: "/editGeneralForumTopic",
      required: [:chat_id, :name],
      optional: []
    },
    close_general_forum_topic: %{
      category: :group_settings,
      path: "/closeGeneralForumTopic",
      required: [:chat_id],
      optional: []
    },
    reopen_general_forum_topic: %{
      category: :group_settings,
      path: "/reopenGeneralForumTopic",
      required: [:chat_id],
      optional: []
    },
    hide_general_forum_topic: %{
      category: :group_settings,
      path: "/hideGeneralForumTopic",
      required: [:chat_id],
      optional: []
    },
    unhide_general_forum_topic: %{
      category: :group_settings,
      path: "/unhideGeneralForumTopic",
      required: [:chat_id],
      optional: []
    },
    unpin_all_general_forum_topic_messages: %{
      category: :group_settings,
      path: "/unpinAllGeneralForumTopicMessages",
      required: [:chat_id],
      optional: []
    },
    send_channel_post: %{
      category: :channel_post_management,
      path: "/sendMessage",
      required: [:chat_id, :text],
      optional: [
        :parse_mode,
        :entities,
        :link_preview_options,
        :disable_notification,
        :protect_content,
        :reply_markup
      ]
    },
    edit_channel_post: %{
      category: :channel_post_management,
      path: "/editMessageText",
      required: [:chat_id, :message_id, :text],
      optional: [:parse_mode, :entities, :link_preview_options, :reply_markup]
    },
    edit_channel_caption: %{
      category: :channel_post_management,
      path: "/editMessageCaption",
      required: [:chat_id, :message_id, :caption],
      optional: [:parse_mode, :caption_entities, :reply_markup]
    },
    delete_channel_post: %{
      category: :channel_post_management,
      path: "/deleteMessage",
      required: [:chat_id, :message_id],
      optional: []
    },
    delete_messages: %{
      category: :content_moderation,
      path: "/deleteMessages",
      required: [:chat_id, :message_ids],
      optional: []
    },
    forward_channel_post: %{
      category: :channel_post_management,
      path: "/forwardMessage",
      required: [:chat_id, :from_chat_id, :message_id],
      optional: [:message_thread_id, :disable_notification, :protect_content]
    },
    copy_channel_post: %{
      category: :channel_post_management,
      path: "/copyMessage",
      required: [:chat_id, :from_chat_id, :message_id],
      optional: [
        :message_thread_id,
        :caption,
        :parse_mode,
        :caption_entities,
        :disable_notification,
        :protect_content,
        :reply_markup
      ]
    }
  }

  @admin_right_requirements %{
    ban_member: [:can_restrict_members],
    unban_member: [:can_restrict_members],
    restrict_member: [:can_restrict_members],
    promote_member: [:can_promote_members],
    demote_member: [:can_promote_members],
    set_admin_title: [:can_promote_members],
    set_member_tag: [:can_manage_tags],
    ban_sender_chat: [:can_restrict_members],
    unban_sender_chat: [:can_restrict_members],
    get_member: [],
    get_admins: [],
    get_member_count: [],
    set_permissions: [:can_restrict_members],
    set_title: [:can_change_info],
    set_description: [:can_change_info],
    delete_photo: [:can_change_info],
    set_slow_mode: [:can_restrict_members],
    create_invite_link: [:can_invite_users],
    edit_invite_link: [:can_invite_users],
    revoke_invite_link: [:can_invite_users],
    approve_join_request: [:can_invite_users],
    decline_join_request: [:can_invite_users],
    pin_message: [:can_pin_messages],
    unpin_message: [:can_pin_messages],
    unpin_all_messages: [:can_pin_messages],
    set_sticker_set: [:can_change_info],
    delete_sticker_set: [:can_change_info],
    create_forum_topic: [:can_manage_topics],
    edit_forum_topic: [:can_manage_topics],
    close_forum_topic: [:can_manage_topics],
    reopen_forum_topic: [:can_manage_topics],
    delete_forum_topic: [:can_manage_topics],
    unpin_all_forum_topic_messages: [:can_manage_topics],
    edit_general_forum_topic: [:can_manage_topics],
    close_general_forum_topic: [:can_manage_topics],
    reopen_general_forum_topic: [:can_manage_topics],
    hide_general_forum_topic: [:can_manage_topics],
    unhide_general_forum_topic: [:can_manage_topics],
    unpin_all_general_forum_topic_messages: [:can_manage_topics],
    send_channel_post: [:can_post_messages],
    edit_channel_post: [:can_edit_messages],
    edit_channel_caption: [:can_edit_messages],
    delete_channel_post: [:can_delete_messages],
    delete_messages: [:can_delete_messages],
    forward_channel_post: [:can_post_messages],
    copy_channel_post: [:can_post_messages],
    moderate_message: [:can_delete_messages],
    log_admin_action: [],
    warn_member: [],
    delete_message: [:can_delete_messages]
  }

  # Admin rights whose presence we insist on verifying before executing a
  # destructive operation (ban/restrict/promote/delete paths). When none of
  # these are required, an action is treated as non-destructive.
  @destructive_rights [:can_restrict_members, :can_promote_members, :can_delete_messages]

  # Actions whose Telegram permission model is not fully captured by chat
  # administrator rights and therefore warrant an explicit capability note.
  @sticker_set_actions [:set_sticker_set, :delete_sticker_set]

  @doc "Returns every operation accepted by `plan/2`."
  @spec known_actions() :: [atom()]
  def known_actions, do: @actions

  @doc """
  Returns the Telegram administrator rights that should be present before executing an action.
  """
  @spec required_admin_rights(atom() | String.t()) :: {:ok, [atom()]} | {:error, String.t()}
  def required_admin_rights(action) do
    with {:ok, normalized_action} <- normalize_preflight_action(action) do
      {:ok, Map.get(@admin_right_requirements, normalized_action, [])}
    end
  end

  @doc """
  Builds a preflight summary for a planned action using optional `bot_admin_rights`.
  """
  @spec preflight_admin_rights(atom() | String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def preflight_admin_rights(action, params \\ %{}) do
    with {:ok, normalized_action} <- normalize_preflight_action(action),
         {:ok, required_rights} <- required_admin_rights(normalized_action) do
      {:ok, build_preflight(normalized_action, required_rights, params)}
    end
  end

  @doc """
  Returns a named `ChatPermissions` template.
  """
  @spec permission_template(atom() | String.t()) :: {:ok, map()} | {:error, String.t()}
  def permission_template(template) do
    case normalize_template(template) do
      {:ok, :standard} ->
        {:ok,
         %{
           can_send_messages: true,
           can_send_audios: true,
           can_send_documents: true,
           can_send_photos: true,
           can_send_videos: true,
           can_send_video_notes: true,
           can_send_voice_notes: true,
           can_send_polls: true,
           can_send_other_messages: true,
           can_add_web_page_previews: true,
           can_react_to_messages: true,
           can_edit_tag: false,
           can_change_info: false,
           can_invite_users: true,
           can_pin_messages: false,
           can_manage_topics: false
         }}

      {:ok, :media_limited} ->
        {:ok,
         %{
           can_send_messages: true,
           can_send_audios: false,
           can_send_documents: false,
           can_send_photos: false,
           can_send_videos: false,
           can_send_video_notes: false,
           can_send_voice_notes: false,
           can_send_polls: true,
           can_send_other_messages: false,
           can_add_web_page_previews: false,
           can_react_to_messages: true,
           can_edit_tag: false,
           can_change_info: false,
           can_invite_users: true,
           can_pin_messages: false,
           can_manage_topics: false
         }}

      {:ok, :read_only} ->
        {:ok, Map.new(@permission_keys, &{&1, false})}

      {:ok, :announcement} ->
        {:ok,
         Map.new(@permission_keys, fn
           :can_react_to_messages -> {:can_react_to_messages, true}
           key -> {key, false}
         end)}

      {:ok, :no_links} ->
        {:ok,
         %{
           can_send_messages: true,
           can_send_audios: true,
           can_send_documents: true,
           can_send_photos: true,
           can_send_videos: true,
           can_send_video_notes: true,
           can_send_voice_notes: true,
           can_send_polls: true,
           can_send_other_messages: true,
           can_add_web_page_previews: false,
           can_react_to_messages: true,
           can_edit_tag: false,
           can_change_info: false,
           can_invite_users: true,
           can_pin_messages: false,
           can_manage_topics: false
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns a named administrator rights template for `promoteChatMember`.
  """
  @spec admin_template(atom() | String.t()) :: {:ok, map()} | {:error, String.t()}
  def admin_template(template) do
    base = Map.new(@admin_permission_keys, &{&1, false})

    case normalize_admin_template(template) do
      {:ok, :none} ->
        {:ok, base}

      {:ok, :moderator} ->
        {:ok,
         %{
           base
           | can_manage_chat: true,
             can_delete_messages: true,
             can_restrict_members: true,
             can_invite_users: true,
             can_pin_messages: true,
             can_manage_topics: true
         }}

      {:ok, :publisher} ->
        {:ok,
         %{
           base
           | can_manage_chat: true,
             can_post_messages: true,
             can_edit_messages: true,
             can_delete_messages: true,
             can_post_stories: true,
             can_edit_stories: true,
             can_delete_stories: true
         }}

      {:ok, :community_manager} ->
        {:ok,
         %{
           base
           | can_manage_chat: true,
             can_delete_messages: true,
             can_manage_video_chats: true,
             can_restrict_members: true,
             can_promote_members: true,
             can_change_info: true,
             can_invite_users: true,
             can_pin_messages: true,
             can_manage_topics: true,
             can_manage_tags: true
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Builds a deterministic group-management plan for a Telegram Bot API operation.
  """
  @spec plan(atom() | String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def plan(action, params \\ %{}) do
    with {:ok, normalized_action} <- normalize_action(action) do
      case normalized_action do
        :moderate_message -> build_moderation_plan(params)
        :log_admin_action -> build_admin_log_plan(params)
        api_action -> build_api_plan(api_action, params)
      end
    end
  end

  @doc """
  Executes every request in a plan through `Lux.Integrations.Telegram.Client`.
  """
  @spec execute(map(), map() | keyword()) :: {:ok, map()} | {:error, map()}
  def execute(%{requests: requests} = plan, opts \\ %{}) when is_list(requests) do
    normalized_opts = normalize_opts(opts)

    case preflight_execution_error(plan, normalized_opts) do
      {:error, _} = error ->
        error

      :ok ->
        execute_requests(plan, requests, normalized_opts)
    end
  end

  @doc """
  Builds a normalized audit entry for an administrative action.
  """
  @spec audit_entry(atom() | String.t(), map(), map()) :: map()
  def audit_entry(action, params, result \\ %{}) do
    status =
      cond do
        Map.get(result, :status) -> Map.get(result, :status)
        Map.get(result, :planned) == true -> :planned
        true -> :recorded
      end

    %{
      id: System.unique_integer([:positive]),
      action: normalize_action_name(action),
      category: value(params, :category),
      chat_id: value(params, :chat_id),
      admin_id: value(params, :admin_id),
      target_user_id: value(params, :target_user_id) || value(params, :user_id),
      message_id: value(params, :message_id),
      reason: value(params, :reason),
      status: status,
      violations: Map.get(result, :violations),
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }
    |> compact()
  end

  @doc "Formats an audit entry as a plain Telegram log message."
  @spec format_audit_entry(map()) :: String.t()
  def format_audit_entry(entry) do
    [
      "Telegram admin action",
      "action=#{entry.action}",
      optional_segment("status", Map.get(entry, :status)),
      optional_segment("chat", Map.get(entry, :chat_id)),
      optional_segment("admin", Map.get(entry, :admin_id)),
      optional_segment("target", Map.get(entry, :target_user_id)),
      optional_segment("message", Map.get(entry, :message_id)),
      optional_segment("reason", Map.get(entry, :reason))
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" | ")
  end

  defp build_api_plan(action, params) do
    spec = Map.fetch!(@api_specs, action)

    with {:ok, payload} <- build_payload(action, spec, params) do
      request = request(spec.category, action, spec.path, payload)
      audit = audit_entry(action, Map.put(params, :category, spec.category), %{planned: true})
      requests = [request] ++ audit_log_requests(audit, params, params)
      preflight = preflight_admin_rights!(action, params)

      {:ok,
       %{
         action: action,
         category: spec.category,
         request_count: length(requests),
         requests: requests,
         preflight: preflight,
         warnings: build_warnings(preflight),
         audit_entry: audit
       }}
    end
  end

  defp build_payload(action, spec, params) do
    with {:ok, required_payload} <- required_payload(params, spec.required),
         {:ok, special_payload} <- special_payload(action, spec, params) do
      payload =
        required_payload
        |> Map.merge(take_params(params, spec.optional))
        |> Map.merge(special_payload)
        |> compact()

      {:ok, payload}
    end
  end

  defp required_payload(params, required_keys) do
    Enum.reduce_while(required_keys, {:ok, %{}}, fn key, {:ok, acc} ->
      case validate_required_key(params, key) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp special_payload(_action, %{permissions: _} = spec, params) do
    default_template = Map.get(spec, :default_permission_template)

    params
    |> resolve_permissions(default_template)
    |> case do
      {:ok, permissions} -> {:ok, %{permissions: permissions}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp special_payload(_action, %{admin_rights: true} = spec, params) do
    default_template = Map.get(spec, :default_admin_template)

    params
    |> resolve_admin_rights(default_template)
    |> case do
      {:ok, rights} -> {:ok, rights}
      {:error, reason} -> {:error, reason}
    end
  end

  defp special_payload(_action, _spec, _params), do: {:ok, %{}}

  defp build_moderation_plan(params) do
    with {:ok, chat_id} <- validate_required_key(params, :chat_id),
         {:ok, text} <- validate_required_key(params, :text),
         {:ok, policy} <- normalize_policy(params),
         {:ok, violations} <- evaluate_content(text, policy, params) do
      severity = moderation_severity(violations)
      moderation_action = resolve_moderation_action(params, policy, severity)
      base_requests = moderation_requests(moderation_action, chat_id, params, policy)

      status =
        if violations == [] do
          :clean
        else
          :flagged
        end

      audit =
        audit_entry(
          :moderate_message,
          Map.put(params, :category, :content_moderation),
          %{status: status, violations: violations}
        )

      requests = base_requests ++ audit_log_requests(audit, params, policy)
      preflight = moderation_preflight_admin_rights(moderation_action, params)

      {:ok,
       %{
         action: :moderate_message,
         category: :content_moderation,
         status: status,
         severity: severity,
         moderation_action: moderation_action,
         violations: violations,
         request_count: length(requests),
         requests: requests,
         preflight: preflight,
         warnings: build_warnings(preflight),
         audit_entry: audit
       }}
    end
  end

  defp build_admin_log_plan(params) do
    logged_action =
      value(params, :logged_action) ||
        value(params, :admin_action) ||
        value(params, :event) ||
        "admin_action"

    audit =
      logged_action
      |> audit_entry(Map.put(params, :category, :admin_logging), %{status: :recorded})
      |> Map.put(:category, :admin_logging)

    requests = audit_log_requests(audit, params, params)
    preflight = preflight_admin_rights!(:log_admin_action, params)

    {:ok,
     %{
       action: :log_admin_action,
       category: :admin_logging,
       request_count: length(requests),
       requests: requests,
       preflight: preflight,
       warnings: build_warnings(preflight),
       audit_entry: audit
     }}
  end

  defp normalize_policy(params) do
    policy = value(params, :policy, %{})

    if is_map(policy) do
      {:ok,
       %{
         blocked_terms: list_value(policy, :blocked_terms),
         blocked_patterns: list_value(policy, :blocked_patterns),
         block_links: boolean_value(policy, :block_links, false),
         max_length: value(policy, :max_length),
         max_mentions: value(policy, :max_mentions),
         max_repeated_chars: value(policy, :max_repeated_chars),
         uppercase_ratio: value(policy, :uppercase_ratio, 0.85),
         min_uppercase_length: value(policy, :min_uppercase_length, 24),
         max_recent_messages: value(policy, :max_recent_messages),
         max_recent_links: value(policy, :max_recent_links),
         duplicate_threshold: value(policy, :duplicate_threshold),
         window_seconds: value(policy, :window_seconds, 60),
         warning_text:
           value(policy, :warning_text, "Please keep the conversation within the group rules."),
         log_chat_id: value(policy, :log_chat_id) || value(params, :log_chat_id),
         action: value(policy, :action)
       }}
    else
      {:error, "policy must be a map"}
    end
  end

  defp evaluate_content(text, policy, params) do
    with {:ok, pattern_violations} <- pattern_violations(text, policy.blocked_patterns) do
      violations =
        []
        |> Kernel.++(blocked_term_violations(text, policy.blocked_terms))
        |> Kernel.++(pattern_violations)
        |> maybe_add(link_violation(text, policy.block_links))
        |> maybe_add(length_violation(text, policy.max_length))
        |> maybe_add(mention_violation(text, policy.max_mentions))
        |> maybe_add(repeated_character_violation(text, policy.max_repeated_chars))
        |> maybe_add(
          uppercase_violation(text, policy.uppercase_ratio, policy.min_uppercase_length)
        )
        |> maybe_add(rate_violation(params, policy))
        |> maybe_add(duplicate_message_violation(text, params, policy))
        |> maybe_add(link_history_violation(text, params, policy))

      {:ok, violations}
    end
  end

  defp blocked_term_violations(text, terms) do
    normalized_text = String.downcase(text)

    terms
    |> Enum.filter(fn term ->
      is_binary(term) and String.trim(term) != "" and
        String.contains?(normalized_text, String.downcase(term))
    end)
    |> Enum.map(fn term -> %{type: :blocked_term, match: term, severity: :medium} end)
  end

  defp pattern_violations(text, patterns) do
    Enum.reduce_while(patterns, {:ok, []}, fn pattern, {:ok, acc} ->
      case pattern_violation(text, pattern) do
        {:ok, nil} -> {:cont, {:ok, acc}}
        {:ok, violation} -> {:cont, {:ok, acc ++ [violation]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp pattern_violation(_text, pattern) when not is_binary(pattern) do
    {:error, "Invalid blocked pattern #{inspect(pattern)}: expected a string"}
  end

  defp pattern_violation(text, pattern) do
    case Regex.compile(pattern, "iu") do
      {:ok, regex} ->
        if Regex.match?(regex, text) do
          {:ok, %{type: :blocked_pattern, match: pattern, severity: :high}}
        else
          {:ok, nil}
        end

      {:error, reason} ->
        {:error, "Invalid blocked pattern #{inspect(pattern)}: #{inspect(reason)}"}
    end
  end

  defp link_violation(text, true) do
    if contains_link?(text) do
      %{type: :link, severity: :medium}
    end
  end

  defp link_violation(_text, _block_links), do: nil

  defp length_violation(text, max_length) when is_integer(max_length) and max_length > 0 do
    length = String.length(text)

    if length > max_length do
      %{type: :length, length: length, max_length: max_length, severity: :medium}
    end
  end

  defp length_violation(_text, _max_length), do: nil

  defp mention_violation(text, max_mentions)
       when is_integer(max_mentions) and max_mentions >= 0 do
    count = Regex.scan(~r/@[A-Za-z0-9_]{5,}/u, text) |> length()

    if count > max_mentions do
      %{type: :mentions, count: count, max_mentions: max_mentions, severity: :low}
    end
  end

  defp mention_violation(_text, _max_mentions), do: nil

  defp repeated_character_violation(text, max_repeated_chars)
       when is_integer(max_repeated_chars) and max_repeated_chars > 1 do
    repeated? =
      text
      |> String.graphemes()
      |> Enum.reduce_while({nil, 0, false}, fn grapheme, {previous, count, _found?} ->
        next_count =
          if grapheme == previous do
            count + 1
          else
            1
          end

        if next_count > max_repeated_chars do
          {:halt, {grapheme, next_count, true}}
        else
          {:cont, {grapheme, next_count, false}}
        end
      end)
      |> elem(2)

    if repeated? do
      %{type: :repeated_characters, max_repeated_chars: max_repeated_chars, severity: :low}
    end
  end

  defp repeated_character_violation(_text, _max_repeated_chars), do: nil

  defp uppercase_violation(text, ratio, min_length)
       when is_number(ratio) and is_integer(min_length) do
    letters =
      text
      |> String.graphemes()
      |> Enum.filter(&Regex.match?(~r/^\p{L}$/u, &1))

    uppercase =
      Enum.count(letters, fn letter -> letter == String.upcase(letter) end)

    if length(letters) >= min_length and length(letters) > 0 and
         uppercase / length(letters) >= ratio do
      %{type: :uppercase_ratio, ratio: uppercase / length(letters), severity: :low}
    end
  end

  defp uppercase_violation(_text, _ratio, _min_length), do: nil

  defp rate_violation(params, %{max_recent_messages: max_recent_messages} = policy)
       when is_integer(max_recent_messages) and max_recent_messages >= 0 do
    recent_count =
      case value(params, :recent_message_count) do
        count when is_integer(count) -> count
        _ -> recent_messages(params, policy) |> length()
      end

    if is_integer(recent_count) and recent_count > max_recent_messages do
      %{
        type: :message_rate,
        recent_message_count: recent_count,
        max_recent_messages: max_recent_messages,
        severity: :high
      }
    end
  end

  defp rate_violation(_params, _policy), do: nil

  defp duplicate_message_violation(text, params, %{duplicate_threshold: threshold} = policy)
       when is_integer(threshold) and threshold > 0 do
    normalized_text = normalize_message_text(text)

    recent_duplicate_count =
      params
      |> recent_messages(policy)
      |> Enum.count(fn message ->
        normalize_message_text(value(message, :text, "")) == normalized_text
      end)

    if normalized_text != "" and recent_duplicate_count + 1 > threshold do
      %{
        type: :duplicate_message,
        recent_duplicate_count: recent_duplicate_count,
        duplicate_threshold: threshold,
        severity: :medium
      }
    end
  end

  defp duplicate_message_violation(_text, _params, _policy), do: nil

  defp link_history_violation(text, params, %{max_recent_links: max_recent_links} = policy)
       when is_integer(max_recent_links) and max_recent_links >= 0 do
    recent_link_count =
      params
      |> recent_messages(policy)
      |> Enum.count(fn message -> contains_link?(value(message, :text, "")) end)

    link_count =
      if contains_link?(text) do
        recent_link_count + 1
      else
        recent_link_count
      end

    if link_count > max_recent_links do
      %{
        type: :link_history,
        recent_link_count: recent_link_count,
        max_recent_links: max_recent_links,
        severity: :medium
      }
    end
  end

  defp link_history_violation(_text, _params, _policy), do: nil

  defp recent_messages(params, policy) do
    params
    |> list_value(:recent_messages)
    |> Enum.filter(fn message ->
      is_map(message) and
        message_matches_context?(message, params) and
        message_in_window?(message, policy.window_seconds)
    end)
  end

  defp message_matches_context?(message, params) do
    context_value_matches?(message, params, :chat_id) and
      context_value_matches?(message, params, :user_id)
  end

  defp context_value_matches?(message, params, key) do
    case {fetch_value(message, key), fetch_value(params, key)} do
      {{:ok, left}, {:ok, right}} -> left == right
      _ -> true
    end
  end

  defp message_in_window?(message, window_seconds)
       when is_integer(window_seconds) and window_seconds >= 0 do
    case value(message, :age_seconds) do
      age_seconds when is_integer(age_seconds) and age_seconds >= 0 ->
        age_seconds <= window_seconds

      _ ->
        true
    end
  end

  defp message_in_window?(_message, _window_seconds), do: true

  defp normalize_message_text(text) when is_binary(text) do
    text
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_message_text(_text), do: ""

  defp contains_link?(text) when is_binary(text) do
    Regex.match?(~r/(https?:\/\/|www\.|t\.me\/|telegram\.me\/)/iu, text)
  end

  defp contains_link?(_text), do: false

  defp moderation_severity([]), do: :none

  defp moderation_severity(violations) do
    cond do
      Enum.any?(violations, &(&1.severity == :high)) -> :high
      Enum.any?(violations, &(&1.severity == :medium)) -> :medium
      true -> :low
    end
  end

  defp resolve_moderation_action(_params, _policy, :none), do: :none

  defp resolve_moderation_action(params, policy, severity) do
    explicit_action = value(params, :moderation_action) || policy.action

    case normalize_moderation_action(explicit_action) do
      {:ok, action} ->
        action

      :error ->
        case severity do
          :high -> :restrict_member
          :medium -> :delete_message
          :low -> :warn_member
        end
    end
  end

  defp moderation_requests(:none, _chat_id, _params, _policy), do: []

  defp moderation_requests(:warn_member, chat_id, params, policy) do
    payload =
      %{
        chat_id: chat_id,
        text: policy.warning_text,
        reply_to_message_id: value(params, :message_id)
      }
      |> compact()

    [request(:content_moderation, :warn_member, "/sendMessage", payload)]
  end

  defp moderation_requests(:delete_message, chat_id, params, _policy) do
    case value(params, :message_id) do
      message_id when is_integer(message_id) ->
        [
          request(:content_moderation, :delete_message, "/deleteMessage", %{
            chat_id: chat_id,
            message_id: message_id
          })
        ]

      _ ->
        []
    end
  end

  defp moderation_requests(:restrict_member, chat_id, params, _policy) do
    delete_requests = moderation_requests(:delete_message, chat_id, params, %{})

    case value(params, :user_id) do
      user_id when is_integer(user_id) ->
        {:ok, permissions} = permission_template(:read_only)

        restrict_payload =
          %{
            chat_id: chat_id,
            user_id: user_id,
            permissions: permissions,
            until_date: value(params, :until_date)
          }
          |> compact()

        delete_requests ++
          [
            request(
              :content_moderation,
              :restrict_member,
              "/restrictChatMember",
              restrict_payload
            )
          ]

      _ ->
        delete_requests
    end
  end

  defp moderation_requests(:ban_member, chat_id, params, _policy) do
    delete_requests = moderation_requests(:delete_message, chat_id, params, %{})

    case value(params, :user_id) do
      user_id when is_integer(user_id) ->
        ban_payload =
          %{
            chat_id: chat_id,
            user_id: user_id,
            until_date: value(params, :until_date),
            revoke_messages: value(params, :revoke_messages)
          }
          |> compact()

        delete_requests ++
          [request(:content_moderation, :ban_member, "/banChatMember", ban_payload)]

      _ ->
        delete_requests
    end
  end

  defp audit_log_requests(audit, params, policy) do
    log_chat_id = value(policy, :log_chat_id) || value(params, :log_chat_id)

    case log_chat_id do
      nil ->
        []

      chat_id ->
        [
          request(:admin_logging, :log_admin_action, "/sendMessage", %{
            chat_id: chat_id,
            text: format_audit_entry(audit),
            disable_notification: true
          })
        ]
    end
  end

  defp request(category, action, path, payload) do
    %{
      method: :post,
      path: path,
      endpoint: path,
      category: category,
      action: action,
      payload: payload
    }
  end

  defp validate_required_key(params, :chat_id), do: validate_chat_id(value(params, :chat_id))

  defp validate_required_key(params, :from_chat_id),
    do: validate_chat_id(value(params, :from_chat_id))

  defp validate_required_key(params, :user_id),
    do: validate_integer(value(params, :user_id), :user_id)

  defp validate_required_key(params, :sender_chat_id),
    do: validate_integer(value(params, :sender_chat_id), :sender_chat_id)

  defp validate_required_key(params, :message_id),
    do: validate_integer(value(params, :message_id), :message_id)

  defp validate_required_key(params, :message_thread_id),
    do: validate_integer(value(params, :message_thread_id), :message_thread_id)

  defp validate_required_key(params, :message_ids),
    do: validate_message_ids(value(params, :message_ids))

  defp validate_required_key(params, :slow_mode_delay) do
    case validate_integer(value(params, :slow_mode_delay), :slow_mode_delay) do
      {:ok, delay} when delay in 0..36_000 -> {:ok, delay}
      {:ok, _delay} -> {:error, "slow_mode_delay must be between 0 and 36000"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_required_key(params, :description),
    do: validate_string(value(params, :description), :description, allow_empty?: true)

  defp validate_required_key(params, key),
    do: validate_string(value(params, key), key, allow_empty?: false)

  defp validate_chat_id(value) when is_integer(value), do: {:ok, value}

  defp validate_chat_id(value) when is_binary(value) do
    if String.trim(value) == "" do
      {:error, "Missing or invalid chat_id"}
    else
      {:ok, value}
    end
  end

  defp validate_chat_id(_value), do: {:error, "Missing or invalid chat_id"}

  defp validate_integer(value, _key) when is_integer(value), do: {:ok, value}
  defp validate_integer(_value, key), do: {:error, "Missing or invalid #{key}"}

  defp validate_message_ids(message_ids) when is_list(message_ids) do
    cond do
      message_ids == [] ->
        {:error, "message_ids must include between 1 and 100 message ids"}

      length(message_ids) > 100 ->
        {:error, "message_ids must include between 1 and 100 message ids"}

      Enum.all?(message_ids, &is_integer/1) ->
        {:ok, message_ids}

      true ->
        {:error, "message_ids must contain only integers"}
    end
  end

  defp validate_message_ids(_message_ids), do: {:error, "Missing or invalid message_ids"}

  defp validate_string(value, _key, allow_empty?: true) when is_binary(value), do: {:ok, value}

  defp validate_string(value, key, allow_empty?: false) when is_binary(value) do
    if String.trim(value) == "" do
      {:error, "Missing or invalid #{key}"}
    else
      {:ok, value}
    end
  end

  defp validate_string(_value, key, _opts), do: {:error, "Missing or invalid #{key}"}

  defp resolve_permissions(params, default_template) do
    raw_permissions = value(params, :permissions)
    template = value(params, :permission_template) || default_template

    cond do
      is_map(raw_permissions) ->
        normalize_flag_map(raw_permissions, @permission_keys, "permissions")

      not is_nil(template) ->
        permission_template(template)

      true ->
        {:error, "Missing or invalid permissions"}
    end
  end

  defp resolve_admin_rights(params, default_template) do
    raw_rights = value(params, :admin_rights) || value(params, :rights)
    template = value(params, :admin_template) || default_template

    cond do
      is_map(raw_rights) ->
        normalize_flag_map(raw_rights, @admin_permission_keys, "admin_rights")

      not is_nil(template) ->
        admin_template(template)

      true ->
        {:error, "Missing or invalid admin_rights"}
    end
  end

  defp normalize_flag_map(raw, allowed_keys, label) do
    result =
      Enum.reduce_while(allowed_keys, {:ok, %{}}, fn key, {:ok, acc} ->
        case fetch_value(raw, key) do
          {:ok, value} when is_boolean(value) -> {:cont, {:ok, Map.put(acc, key, value)}}
          {:ok, nil} -> {:cont, {:ok, acc}}
          {:ok, _value} -> {:halt, {:error, "#{label}.#{key} must be a boolean"}}
          :error -> {:cont, {:ok, acc}}
        end
      end)

    case result do
      {:ok, flags} when map_size(flags) > 0 -> {:ok, flags}
      {:ok, _flags} -> {:error, "#{label} must include at least one supported flag"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_action(action) when is_atom(action) do
    if action in @actions do
      {:ok, action}
    else
      {:error, "Unsupported Telegram group action: #{inspect(action)}"}
    end
  end

  defp normalize_action(action) when is_binary(action) do
    action
    |> String.trim()
    |> String.replace("-", "_")
    |> then(fn key ->
      case Map.fetch(@action_aliases, key) do
        {:ok, action} -> {:ok, action}
        :error -> {:error, "Unsupported Telegram group action: #{inspect(action)}"}
      end
    end)
  end

  defp normalize_action(action),
    do: {:error, "Unsupported Telegram group action: #{inspect(action)}"}

  defp normalize_preflight_action(action) do
    case normalize_action(action) do
      {:ok, normalized} ->
        {:ok, normalized}

      {:error, _reason} ->
        case normalize_moderation_action(action) do
          {:ok, normalized} -> {:ok, normalized}
          :error -> {:error, "Unsupported Telegram group action: #{inspect(action)}"}
        end
    end
  end

  defp normalize_action_name(action) do
    case normalize_action(action) do
      {:ok, normalized} -> Atom.to_string(normalized)
      {:error, _reason} when is_binary(action) -> action
      {:error, _reason} -> inspect(action)
    end
  end

  defp normalize_template(template)
       when template in [:standard, :media_limited, :read_only, :announcement, :no_links],
       do: {:ok, template}

  defp normalize_template(template) when is_binary(template) do
    case String.replace(template, "-", "_") do
      "standard" -> {:ok, :standard}
      "media_limited" -> {:ok, :media_limited}
      "read_only" -> {:ok, :read_only}
      "announcement" -> {:ok, :announcement}
      "no_links" -> {:ok, :no_links}
      _ -> {:error, "Unsupported permission template: #{inspect(template)}"}
    end
  end

  defp normalize_template(template),
    do: {:error, "Unsupported permission template: #{inspect(template)}"}

  defp normalize_admin_template(template)
       when template in [:none, :moderator, :publisher, :community_manager],
       do: {:ok, template}

  defp normalize_admin_template(template) when is_binary(template) do
    case String.replace(template, "-", "_") do
      "none" -> {:ok, :none}
      "moderator" -> {:ok, :moderator}
      "publisher" -> {:ok, :publisher}
      "community_manager" -> {:ok, :community_manager}
      _ -> {:error, "Unsupported admin template: #{inspect(template)}"}
    end
  end

  defp normalize_admin_template(template),
    do: {:error, "Unsupported admin template: #{inspect(template)}"}

  defp normalize_moderation_action(action)
       when action in [:none, :warn_member, :delete_message, :restrict_member, :ban_member],
       do: {:ok, action}

  defp normalize_moderation_action(action) when is_binary(action) do
    case String.replace(action, "-", "_") do
      "none" -> {:ok, :none}
      "warn_member" -> {:ok, :warn_member}
      "delete_message" -> {:ok, :delete_message}
      "restrict_member" -> {:ok, :restrict_member}
      "ban_member" -> {:ok, :ban_member}
      _ -> :error
    end
  end

  defp normalize_moderation_action(_action), do: :error

  defp preflight_admin_rights!(action, params) do
    {:ok, preflight} = preflight_admin_rights(action, params)
    preflight
  end

  defp moderation_preflight_admin_rights(:restrict_member, params) do
    build_preflight(:restrict_member, [:can_delete_messages, :can_restrict_members], params)
  end

  defp moderation_preflight_admin_rights(:ban_member, params) do
    build_preflight(:ban_member, [:can_delete_messages, :can_restrict_members], params)
  end

  defp moderation_preflight_admin_rights(action, params) do
    preflight_admin_rights!(action, params)
  end

  defp build_preflight(action, required_rights, params) do
    required_rights = Enum.uniq(required_rights)
    available_rights = value(params, :bot_admin_rights)
    configured = is_map(available_rights)
    destructive? = Enum.any?(required_rights, &(&1 in @destructive_rights))

    missing_rights =
      if configured do
        Enum.reject(required_rights, &right_enabled?(available_rights, &1))
      else
        []
      end

    %{
      action: action,
      required_rights: required_rights,
      configured: configured,
      destructive: destructive?,
      # `verified` is only true when the caller supplied bot_admin_rights AND
      # every required right is present. It stays false when rights are absent,
      # so destructive execution cannot silently proceed unverified.
      verified: configured and missing_rights == [],
      ok: missing_rights == [],
      missing_rights: missing_rights
    }
  end

  defp build_warnings(preflight) do
    []
    |> maybe_add(unverified_admin_warning(preflight))
    |> maybe_add(sticker_set_warning(Map.get(preflight, :action)))
  end

  defp unverified_admin_warning(%{destructive: true, verified: false} = preflight) do
    rights = Enum.map_join(Map.get(preflight, :required_rights, []), ", ", &Atom.to_string/1)

    "Destructive action #{Map.get(preflight, :action)} has unverified bot admin rights " <>
      "(#{rights}). Execution is blocked unless bot_admin_rights confirm these rights or " <>
      "allow_unverified_admin_rights: true is passed."
  end

  defp unverified_admin_warning(_preflight), do: nil

  defp sticker_set_warning(action) when action in @sticker_set_actions do
    "#{action} may also require the chat-level can_set_sticker_set capability, which is only " <>
      "observable through getChat and is not part of bot_admin_rights. Verify it before live " <>
      "execution."
  end

  defp sticker_set_warning(_action), do: nil

  defp right_enabled?(rights, right) do
    case fetch_value(rights, right) do
      {:ok, true} -> true
      _ -> false
    end
  end

  defp execute_requests(plan, requests, opts) do
    base_opts = take_params(opts, [:plug, :token])

    # Execute requests in order and stop at the first failure so a partial
    # plan (e.g. delete + ban + audit log) cannot deliver a later audit-log
    # message implying the earlier destructive request succeeded.
    {results, halted?} =
      Enum.reduce_while(requests, {[], false}, fn request, {acc, _halted?} ->
        request_opts = Map.put(base_opts, :json, Map.get(request, :payload, %{}))

        case Client.request(request.method, request.path, request_opts) do
          {:ok, response} ->
            {:cont, {acc ++ [{:ok, %{request: request, response: response}}], false}}

          {:error, error} ->
            {:halt, {acc ++ [{:error, %{request: request, error: error}}], true}}
        end
      end)

    if halted? do
      {:error, %{plan: plan, results: results}}
    else
      {:ok,
       plan
       |> Map.put(:executed, true)
       |> Map.put(:results, Enum.map(results, fn {:ok, result} -> result end))}
    end
  end

  defp preflight_execution_error(%{preflight: preflight} = plan, opts) when is_map(preflight) do
    cond do
      Map.get(preflight, :configured) and not Map.get(preflight, :ok, true) ->
        missing = Enum.map_join(Map.get(preflight, :missing_rights, []), ", ", &Atom.to_string/1)
        execution_block(plan, "Missing required Telegram admin rights: #{missing}")

      Map.get(preflight, :destructive) and not Map.get(preflight, :verified) and
          not allow_unverified_admin_rights?(opts) ->
        required =
          Enum.map_join(Map.get(preflight, :required_rights, []), ", ", &Atom.to_string/1)

        execution_block(
          plan,
          "Refusing to execute destructive Telegram action " <>
            "#{Map.get(preflight, :action)} without verified bot_admin_rights. Provide " <>
            "bot_admin_rights confirming #{required} or pass allow_unverified_admin_rights: true."
        )

      true ->
        :ok
    end
  end

  defp preflight_execution_error(_plan, _opts), do: :ok

  defp execution_block(plan, message) do
    {:error, %{plan: plan, results: [{:error, %{request: nil, error: message}}]}}
  end

  defp allow_unverified_admin_rights?(opts) do
    case fetch_value(opts, :allow_unverified_admin_rights) do
      {:ok, value} -> value in [true, "true", 1, "1"]
      :error -> false
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

  defp list_value(params, key) do
    case value(params, key, []) do
      values when is_list(values) -> values
      value when is_binary(value) -> [value]
      _ -> []
    end
  end

  defp boolean_value(params, key, default) do
    case value(params, key, default) do
      value when is_boolean(value) -> value
      _ -> default
    end
  end

  defp compact(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp maybe_add(values, nil), do: values
  defp maybe_add(values, value), do: values ++ [value]

  defp optional_segment(_name, nil), do: nil
  defp optional_segment(name, value), do: "#{name}=#{value}"

  defp normalize_opts(opts) when is_map(opts), do: opts
  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)
end
