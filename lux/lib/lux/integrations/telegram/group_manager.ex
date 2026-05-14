defmodule Lux.Integrations.Telegram.GroupManager do
  @moduledoc """
  Telegram group and channel management planning helpers.

  The functions in this module build normalized Telegram Bot API action plans. They do not perform
  network requests, which keeps moderation, permission, and audit workflows deterministic and easy
  to test before a bot transport executes the resulting plans.
  """

  @member_actions [:restrict, :ban, :unban, :promote, :demote, :invite]
  @setting_actions [:title, :description, :permissions, :slow_mode, :pin_message]
  @post_actions [:send, :edit, :pin]

  @base_permissions %{
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
    can_change_info: false,
    can_invite_users: true,
    can_pin_messages: false,
    can_manage_topics: false
  }

  @read_only_permissions Map.new(@base_permissions, fn
                           {:can_invite_users, _value} -> {:can_invite_users, false}
                           {:can_change_info, _value} -> {:can_change_info, false}
                           {:can_pin_messages, _value} -> {:can_pin_messages, false}
                           {:can_manage_topics, _value} -> {:can_manage_topics, false}
                           {key, _value} -> {key, false}
                         end)

  @moderator_permissions %{
    can_manage_chat: true,
    can_delete_messages: true,
    can_manage_video_chats: true,
    can_restrict_members: true,
    can_promote_members: false,
    can_change_info: false,
    can_invite_users: true,
    can_pin_messages: true,
    can_post_messages: false,
    can_edit_messages: false,
    can_manage_topics: true
  }

  @doc "Returns a Telegram chat permission template."
  def permission_template(template, overrides \\ %{}) do
    template
    |> normalize_template()
    |> case do
      :default ->
        {:ok, merge_permissions(@base_permissions, overrides)}

      :media_limited ->
        {:ok, merge_permissions(media_limited_permissions(), overrides)}

      :read_only ->
        {:ok, merge_permissions(@read_only_permissions, overrides)}

      :no_links ->
        {:ok,
         merge_permissions(
           Map.put(@base_permissions, :can_add_web_page_previews, false),
           overrides
         )}

      :moderator ->
        {:ok, merge_permissions(@moderator_permissions, overrides)}

      :channel_publisher ->
        {:ok, merge_permissions(channel_publisher_permissions(), overrides)}

      _unknown ->
        {:error, :unknown_permission_template}
    end
  end

  @doc "Builds a role-to-permission matrix for a group."
  def permission_system(attrs \\ %{}) do
    with {:ok, member} <- permission_template(:default),
         {:ok, restricted} <- permission_template(:media_limited),
         {:ok, read_only} <- permission_template(:read_only),
         {:ok, moderator} <- permission_template(:moderator),
         {:ok, publisher} <- permission_template(:channel_publisher) do
      {:ok,
       %{
         chat_id: value(attrs, :chat_id),
         roles: %{
           member: %{chat_permissions: member},
           restricted: %{chat_permissions: restricted},
           read_only: %{chat_permissions: read_only},
           moderator: %{admin_permissions: moderator},
           channel_publisher: %{admin_permissions: publisher}
         },
         default_role: value(attrs, :default_role, :member),
         generated_at: timestamp(value(attrs, :now))
       }}
    end
  end

  @doc "Plans member management actions such as restrict, ban, unban, promote, demote, or invite."
  def member_action_plan(attrs) when is_map(attrs) do
    action = attrs |> value(:action) |> normalize_atom()

    with :ok <- ensure_known(action, @member_actions, :unknown_member_action),
         {:ok, chat_id} <- required(attrs, :chat_id),
         {:ok, user_id} <- required(attrs, :user_id) do
      request =
        case action do
          :restrict -> restrict_request(chat_id, user_id, attrs)
          :ban -> ban_request(chat_id, user_id, attrs)
          :unban -> unban_request(chat_id, user_id, attrs)
          :promote -> promote_request(chat_id, user_id, attrs)
          :demote -> demote_request(chat_id, user_id, attrs)
          :invite -> invite_request(chat_id, attrs)
        end

      {:ok,
       plan(:member_management, action, request, attrs)
       |> Map.put(:target_user_id, user_id)}
    end
  end

  @doc "Evaluates a message against moderation rules and returns safe action plans."
  def moderate_content(message, rules \\ %{}) when is_map(message) do
    text = message |> value(:text, "") |> to_string()
    findings = moderation_findings(text, message, rules)
    severity = moderation_severity(findings)
    action = moderation_action(severity, rules)

    requests =
      case action do
        :allow ->
          []

        :warn ->
          [warning_request(message, findings, rules)]

        :delete ->
          [delete_message_request(message), warning_request(message, findings, rules)]

        :restrict ->
          [delete_message_request(message), restrict_from_message_request(message, rules)]

        :ban ->
          [delete_message_request(message), ban_from_message_request(message, rules)]
      end

    {:ok,
     %{
       status: action,
       severity: severity,
       findings: findings,
       requests: Enum.reject(requests, &is_nil/1),
       evaluated_at: timestamp(value(rules, :now))
     }}
  end

  @doc "Builds a moderation action plan from a message and policy."
  def moderation_action_plan(attrs) when is_map(attrs) do
    message = value(attrs, :message, attrs)
    rules = value(attrs, :rules, %{})

    with {:ok, moderation} <- moderate_content(message, rules) do
      {:ok,
       %{
         category: :moderation,
         action: moderation.status,
         chat_id: value(message, :chat_id),
         target_user_id: value(message, :user_id, value(message, :from_user_id)),
         moderation: moderation,
         audit:
           audit_log_entry(%{
             action: moderation.status,
             actor_id: value(attrs, :actor_id, "bot"),
             chat_id: value(message, :chat_id),
             target_user_id: value(message, :user_id, value(message, :from_user_id)),
             reason: moderation.findings,
             request_count: length(moderation.requests),
             now: value(attrs, :now)
           })
       }}
    end
  end

  @doc "Detects repeated-message and burst spam patterns from recent message events."
  def spam_protection(events, rules \\ %{}) when is_list(events) do
    duplicate_threshold = value(rules, :duplicate_threshold, 3)
    burst_threshold = value(rules, :burst_threshold, 5)

    duplicate_flags =
      events
      |> Enum.group_by(fn event ->
        {value(event, :user_id), normalize_text(value(event, :text, ""))}
      end)
      |> Enum.filter(fn {{_user_id, text}, group} ->
        text != "" and length(group) >= duplicate_threshold
      end)
      |> Enum.map(fn {{user_id, text}, group} ->
        %{type: :duplicate_text, user_id: user_id, text: text, count: length(group)}
      end)

    burst_flags =
      events
      |> Enum.group_by(&value(&1, :user_id))
      |> Enum.filter(fn {_user_id, group} -> length(group) >= burst_threshold end)
      |> Enum.map(fn {user_id, group} ->
        %{type: :message_burst, user_id: user_id, count: length(group)}
      end)

    {:ok,
     %{
       flags: duplicate_flags ++ burst_flags,
       event_count: length(events),
       evaluated_at: timestamp(value(rules, :now))
     }}
  end

  @doc "Plans group setting changes."
  def group_settings_plan(attrs) when is_map(attrs) do
    action = attrs |> value(:action) |> normalize_atom()

    with :ok <- ensure_known(action, @setting_actions, :unknown_setting_action),
         {:ok, chat_id} <- required(attrs, :chat_id) do
      request =
        case action do
          :title ->
            request("setChatTitle", %{chat_id: chat_id, title: value(attrs, :title)})

          :description ->
            request("setChatDescription", %{
              chat_id: chat_id,
              description: value(attrs, :description)
            })

          :permissions ->
            set_permissions_request(chat_id, attrs)

          :slow_mode ->
            slow_mode_request(chat_id, attrs)

          :pin_message ->
            pin_message_request(chat_id, attrs)
        end

      {:ok, plan(:group_settings, action, request, attrs)}
    end
  end

  @doc "Plans channel post operations."
  def channel_post_plan(attrs) when is_map(attrs) do
    action = attrs |> value(:action, :send) |> normalize_atom()

    with :ok <- ensure_known(action, @post_actions, :unknown_post_action),
         {:ok, chat_id} <- required(attrs, :chat_id) do
      request =
        case action do
          :send -> send_post_request(chat_id, attrs)
          :edit -> edit_post_request(chat_id, attrs)
          :pin -> pin_message_request(chat_id, attrs)
        end

      {:ok, plan(:channel_post, action, request, attrs)}
    end
  end

  @doc "Builds a normalized admin audit log entry."
  def audit_log_entry(attrs) when is_map(attrs) do
    %{
      id: value(attrs, :id) || audit_id(attrs),
      action: attrs |> value(:action) |> normalize_atom(),
      actor_id: value(attrs, :actor_id),
      chat_id: value(attrs, :chat_id),
      target_user_id: value(attrs, :target_user_id),
      reason: value(attrs, :reason),
      request_count: value(attrs, :request_count, 1),
      metadata: value(attrs, :metadata, %{}),
      created_at: timestamp(value(attrs, :now))
    }
  end

  @doc "Filters and summarizes admin audit entries."
  def audit_log(entries, filters \\ %{}) when is_list(entries) do
    filtered =
      Enum.filter(entries, fn entry ->
        filter_match?(entry, :chat_id, value(filters, :chat_id)) and
          filter_match?(entry, :actor_id, value(filters, :actor_id)) and
          filter_match?(entry, :action, value(filters, :action))
      end)

    {:ok,
     %{
       entries: filtered,
       count: length(filtered),
       actions: frequency(filtered, :action),
       actors: frequency(filtered, :actor_id)
     }}
  end

  defp restrict_request(chat_id, user_id, attrs) do
    {:ok, permissions} = permission_template(value(attrs, :permissions, :read_only))

    request("restrictChatMember", %{
      chat_id: chat_id,
      user_id: user_id,
      permissions: permissions,
      until_date: value(attrs, :until_date)
    })
  end

  defp ban_request(chat_id, user_id, attrs) do
    request("banChatMember", %{
      chat_id: chat_id,
      user_id: user_id,
      until_date: value(attrs, :until_date),
      revoke_messages: value(attrs, :revoke_messages, true)
    })
  end

  defp unban_request(chat_id, user_id, attrs) do
    request("unbanChatMember", %{
      chat_id: chat_id,
      user_id: user_id,
      only_if_banned: value(attrs, :only_if_banned, true)
    })
  end

  defp promote_request(chat_id, user_id, attrs) do
    {:ok, permissions} = permission_template(value(attrs, :permissions, :moderator))

    request(
      "promoteChatMember",
      permissions
      |> Map.merge(%{chat_id: chat_id, user_id: user_id})
      |> Map.put(:is_anonymous, value(attrs, :is_anonymous, false))
    )
  end

  defp demote_request(chat_id, user_id, _attrs) do
    request(
      "promoteChatMember",
      @moderator_permissions
      |> Map.new(fn {key, _value} -> {key, false} end)
      |> Map.merge(%{chat_id: chat_id, user_id: user_id})
    )
  end

  defp invite_request(chat_id, attrs) do
    request("createChatInviteLink", %{
      chat_id: chat_id,
      name: value(attrs, :name, "member invite"),
      expire_date: value(attrs, :expire_date),
      member_limit: value(attrs, :member_limit, 1),
      creates_join_request: value(attrs, :creates_join_request, false)
    })
  end

  defp set_permissions_request(chat_id, attrs) do
    {:ok, permissions} = permission_template(value(attrs, :permissions, :default))

    request("setChatPermissions", %{
      chat_id: chat_id,
      permissions: permissions,
      use_independent_chat_permissions: true
    })
  end

  defp slow_mode_request(chat_id, attrs) do
    request("setChatSlowModeDelay", %{
      chat_id: chat_id,
      slow_mode_delay: value(attrs, :slow_mode_delay, value(attrs, :delay, 0))
    })
  end

  defp pin_message_request(chat_id, attrs) do
    request("pinChatMessage", %{
      chat_id: chat_id,
      message_id: value(attrs, :message_id),
      disable_notification: value(attrs, :disable_notification, true)
    })
  end

  defp send_post_request(chat_id, attrs) do
    request("sendMessage", %{
      chat_id: chat_id,
      text: value(attrs, :text),
      parse_mode: value(attrs, :parse_mode),
      disable_notification: value(attrs, :disable_notification, false),
      protect_content: value(attrs, :protect_content, false)
    })
  end

  defp edit_post_request(chat_id, attrs) do
    request("editMessageText", %{
      chat_id: chat_id,
      message_id: value(attrs, :message_id),
      text: value(attrs, :text),
      parse_mode: value(attrs, :parse_mode)
    })
  end

  defp warning_request(message, findings, rules) do
    chat_id = value(message, :chat_id)
    user_id = value(message, :user_id, value(message, :from_user_id))

    request("sendMessage", %{
      chat_id: chat_id,
      text: value(rules, :warning_text, "Please follow the group rules."),
      reply_to_message_id: value(message, :message_id),
      metadata: %{target_user_id: user_id, findings: findings}
    })
  end

  defp delete_message_request(message) do
    with chat_id when not is_nil(chat_id) <- value(message, :chat_id),
         message_id when not is_nil(message_id) <- value(message, :message_id) do
      request("deleteMessage", %{chat_id: chat_id, message_id: message_id})
    else
      _missing -> nil
    end
  end

  defp restrict_from_message_request(message, rules) do
    attrs = %{
      chat_id: value(message, :chat_id),
      user_id: value(message, :user_id, value(message, :from_user_id)),
      permissions: value(rules, :restriction_permissions, :read_only),
      until_date: value(rules, :restriction_until_date)
    }

    restrict_request(attrs.chat_id, attrs.user_id, attrs)
  end

  defp ban_from_message_request(message, rules) do
    attrs = %{
      chat_id: value(message, :chat_id),
      user_id: value(message, :user_id, value(message, :from_user_id)),
      until_date: value(rules, :ban_until_date),
      revoke_messages: true
    }

    ban_request(attrs.chat_id, attrs.user_id, attrs)
  end

  defp moderation_findings(text, message, rules) do
    []
    |> maybe_flag(:blocked_word, contains_any?(text, value(rules, :blocked_words, [])))
    |> maybe_flag(:link, link?(text) and not value(rules, :allow_links, false))
    |> maybe_flag(:mention_spam, mention_count(text) >= value(rules, :mention_limit, 6))
    |> maybe_flag(
      :caps_spam,
      caps_ratio(text) >= value(rules, :caps_ratio, 0.75) and String.length(text) >= 12
    )
    |> maybe_flag(
      :forwarded,
      value(message, :forwarded, false) and value(rules, :block_forwarded, false)
    )
    |> maybe_flag(
      :media_not_allowed,
      media_message?(message) and value(rules, :block_media, false)
    )
  end

  defp moderation_severity(findings) do
    cond do
      :blocked_word in findings -> :high
      Enum.any?(findings, &(&1 in [:link, :mention_spam])) -> :medium
      findings == [] -> :none
      true -> :low
    end
  end

  defp moderation_action(:none, _rules), do: :allow
  defp moderation_action(:low, rules), do: value(rules, :low_action, :warn) |> normalize_atom()

  defp moderation_action(:medium, rules),
    do: value(rules, :medium_action, :delete) |> normalize_atom()

  defp moderation_action(:high, rules),
    do: value(rules, :high_action, :restrict) |> normalize_atom()

  defp media_limited_permissions do
    @base_permissions
    |> Map.merge(%{
      can_send_audios: false,
      can_send_documents: false,
      can_send_photos: false,
      can_send_videos: false,
      can_send_video_notes: false,
      can_send_voice_notes: false,
      can_send_other_messages: false,
      can_add_web_page_previews: false
    })
  end

  defp channel_publisher_permissions do
    @moderator_permissions
    |> Map.merge(%{
      can_post_messages: true,
      can_edit_messages: true,
      can_delete_messages: true,
      can_manage_chat: true
    })
  end

  defp merge_permissions(template, overrides) do
    overrides =
      overrides
      |> normalize_map()
      |> Map.take(Map.keys(template))

    Map.merge(template, overrides)
  end

  defp plan(category, action, request, attrs) do
    %{
      id: value(attrs, :id) || plan_id(category, action, request),
      category: category,
      action: action,
      request: request,
      audit:
        audit_log_entry(%{
          action: action,
          actor_id: value(attrs, :actor_id, "bot"),
          chat_id: request.payload.chat_id,
          target_user_id: value(request.payload, :user_id),
          reason: value(attrs, :reason),
          now: value(attrs, :now)
        }),
      created_at: timestamp(value(attrs, :now))
    }
  end

  defp request(method, payload) do
    %{
      method: method,
      endpoint: "/" <> method,
      payload: drop_nil(payload)
    }
  end

  defp audit_id(attrs), do: "tgl_audit_" <> short_hash("#{inspect(attrs)}")

  defp plan_id(category, action, request),
    do: "tgl_plan_" <> short_hash("#{category}:#{action}:#{inspect(request)}")

  defp short_hash(value) do
    :sha256
    |> :crypto.hash(to_string(value))
    |> binary_part(0, 8)
    |> Base.encode16(case: :lower)
  end

  defp filter_match?(_entry, _key, nil), do: true
  defp filter_match?(entry, key, expected), do: value(entry, key) == expected

  defp frequency(entries, key) do
    entries
    |> Enum.map(&value(&1, key))
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
  end

  defp contains_any?(text, words) do
    normalized = String.downcase(text)
    Enum.any?(words, &String.contains?(normalized, String.downcase(to_string(&1))))
  end

  defp link?(text), do: Regex.match?(~r/https?:\/\/|t\.me\/|www\./i, text)

  defp mention_count(text), do: Regex.scan(~r/@[a-zA-Z0-9_]{3,}/, text) |> length()

  defp caps_ratio(text) do
    letters = Regex.scan(~r/[[:alpha:]]/, text) |> List.flatten()

    case letters do
      [] ->
        0.0

      letters ->
        caps = Enum.count(letters, &(&1 == String.upcase(&1) and &1 != String.downcase(&1)))
        caps / length(letters)
    end
  end

  defp media_message?(message) do
    Enum.any?(
      [:photo, :video, :document, :audio, :voice, :animation],
      &truthy?(value(message, &1))
    )
  end

  defp normalize_text(text) do
    text
    |> to_string()
    |> String.downcase()
    |> String.trim()
  end

  defp maybe_flag(flags, flag, true), do: [flag | flags]
  defp maybe_flag(flags, _flag, _false), do: flags

  defp required(map, key) do
    case value(map, key) do
      nil -> {:error, {:missing_required, key}}
      "" -> {:error, {:missing_required, key}}
      value -> {:ok, value}
    end
  end

  defp ensure_known(value, allowed, error),
    do: if(value in allowed, do: :ok, else: {:error, error})

  defp normalize_template(template) do
    template
    |> normalize_atom()
    |> case do
      :default_group -> :default
      :default_member -> :default
      other -> other
    end
  end

  defp normalize_map(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {normalize_atom(key), value} end)
  end

  defp normalize_map(_map), do: %{}

  defp drop_nil(map) do
    map
    |> normalize_map()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp value(map, key, default \\ nil)

  defp value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, to_string(key), default))

  defp value(_map, _key, default), do: default

  defp normalize_atom(value) when is_atom(value), do: value

  defp normalize_atom(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace("-", "_")
    |> String.to_atom()
  end

  defp normalize_atom(value), do: value

  defp truthy?(value), do: value in [true, "true", "1", 1, true]

  defp timestamp(nil), do: DateTime.utc_now() |> DateTime.to_iso8601()
  defp timestamp(%DateTime{} = now), do: DateTime.to_iso8601(now)
  defp timestamp(now) when is_binary(now), do: now
end
