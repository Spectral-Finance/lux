defmodule Lux.Integrations.Telegram.GroupManager do
  @moduledoc """
  Helpers for Telegram group and channel management workflows.

  The module builds normalized Telegram Bot API action plans for moderation,
  permissions, channel posts, and admin audit logs. Callers can execute the
  returned `%{method, endpoint, payload}` through `Lux.Integrations.Telegram.Client`.
  """

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
    :can_change_info,
    :can_invite_users,
    :can_pin_messages,
    :can_manage_topics
  ]

  @admin_permission_keys [
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
    :can_manage_topics
  ]

  @member_templates %{
    default_member: %{
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
      can_invite_users: true
    },
    media_allowed: %{
      can_send_messages: true,
      can_send_audios: true,
      can_send_documents: true,
      can_send_photos: true,
      can_send_videos: true,
      can_send_video_notes: true,
      can_send_voice_notes: true,
      can_send_polls: false,
      can_send_other_messages: false,
      can_add_web_page_previews: false,
      can_invite_users: true
    },
    read_only: %{
      can_send_messages: false,
      can_send_audios: false,
      can_send_documents: false,
      can_send_photos: false,
      can_send_videos: false,
      can_send_video_notes: false,
      can_send_voice_notes: false,
      can_send_polls: false,
      can_send_other_messages: false,
      can_add_web_page_previews: false,
      can_invite_users: false
    }
  }

  @admin_templates %{
    moderator: %{
      can_manage_chat: true,
      can_delete_messages: true,
      can_manage_video_chats: false,
      can_restrict_members: true,
      can_promote_members: false,
      can_change_info: false,
      can_invite_users: true,
      can_pin_messages: true,
      can_manage_topics: true
    },
    publisher: %{
      can_manage_chat: false,
      can_delete_messages: false,
      can_manage_video_chats: false,
      can_restrict_members: false,
      can_promote_members: false,
      can_change_info: false,
      can_invite_users: false,
      can_post_messages: true,
      can_edit_messages: true
    }
  }

  @doc """
  Returns a normalized chat/member permission map from a named template.
  """
  @spec member_permissions(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def member_permissions(template, overrides \\ %{}) when is_atom(template) do
    build_permissions(@member_templates, @permission_keys, template, overrides)
  end

  @doc """
  Returns a normalized administrator permission map from a named template.
  """
  @spec admin_permissions(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def admin_permissions(template, overrides \\ %{}) when is_atom(template) do
    build_permissions(@admin_templates, @admin_permission_keys, template, overrides)
  end

  @doc """
  Builds a Telegram `restrictChatMember` action plan.
  """
  @spec restrict_member(term(), term(), atom() | map(), map()) :: {:ok, map()} | {:error, String.t()}
  def restrict_member(chat_id, user_id, permissions_or_template \\ :read_only, opts \\ %{}) do
    with {:ok, permissions} <- resolve_member_permissions(permissions_or_template) do
      payload =
        %{
          chat_id: chat_id,
          user_id: user_id,
          permissions: permissions
        }
        |> put_optional(:until_date, value(opts, :until_date))
        |> put_optional(:use_independent_chat_permissions, value(opts, :use_independent_chat_permissions))

      {:ok, action(:post, "/restrictChatMember", payload)}
    end
  end

  @doc """
  Builds a Telegram `banChatMember` action plan.
  """
  @spec ban_member(term(), term(), map()) :: {:ok, map()}
  def ban_member(chat_id, user_id, opts \\ %{}) do
    payload =
      %{
        chat_id: chat_id,
        user_id: user_id
      }
      |> put_optional(:until_date, value(opts, :until_date))
      |> put_optional(:revoke_messages, value(opts, :revoke_messages))

    {:ok, action(:post, "/banChatMember", payload)}
  end

  @doc """
  Builds a Telegram `unbanChatMember` action plan.
  """
  @spec unban_member(term(), term(), map()) :: {:ok, map()}
  def unban_member(chat_id, user_id, opts \\ %{}) do
    payload =
      %{
        chat_id: chat_id,
        user_id: user_id
      }
      |> put_optional(:only_if_banned, value(opts, :only_if_banned))

    {:ok, action(:post, "/unbanChatMember", payload)}
  end

  @doc """
  Builds a Telegram `promoteChatMember` action plan from an admin template.
  """
  @spec promote_member(term(), term(), atom() | map(), map()) :: {:ok, map()} | {:error, String.t()}
  def promote_member(chat_id, user_id, permissions_or_template \\ :moderator, opts \\ %{}) do
    with {:ok, permissions} <- resolve_admin_permissions(permissions_or_template) do
      payload =
        %{chat_id: chat_id, user_id: user_id}
        |> Map.merge(permissions)
        |> put_optional(:is_anonymous, value(opts, :is_anonymous))
        |> put_optional(:custom_title, value(opts, :custom_title))

      {:ok, action(:post, "/promoteChatMember", payload)}
    end
  end

  @doc """
  Builds a Telegram `setChatPermissions` action plan.
  """
  @spec set_chat_permissions(term(), atom() | map(), map()) :: {:ok, map()} | {:error, String.t()}
  def set_chat_permissions(chat_id, permissions_or_template \\ :default_member, opts \\ %{}) do
    with {:ok, permissions} <- resolve_member_permissions(permissions_or_template) do
      payload =
        %{
          chat_id: chat_id,
          permissions: permissions
        }
        |> put_optional(:use_independent_chat_permissions, value(opts, :use_independent_chat_permissions))

      {:ok, action(:post, "/setChatPermissions", payload)}
    end
  end

  @doc """
  Builds a Telegram `sendMessage` action plan for channel or group posts.
  """
  @spec channel_post(term(), String.t(), map()) :: {:ok, map()}
  def channel_post(chat_id, text, opts \\ %{}) when is_binary(text) do
    payload =
      %{
        chat_id: chat_id,
        text: text
      }
      |> put_optional(:parse_mode, value(opts, :parse_mode))
      |> put_optional(:disable_notification, value(opts, :disable_notification))
      |> put_optional(:message_thread_id, value(opts, :message_thread_id))
      |> put_optional(:reply_markup, value(opts, :reply_markup))

    {:ok, action(:post, "/sendMessage", payload)}
  end

  @doc """
  Creates a stable audit-log entry for moderation and admin actions.
  """
  @spec admin_log_entry(atom(), map()) :: map()
  def admin_log_entry(action_name, attrs) when is_atom(action_name) and is_map(attrs) do
    %{
      action: action_name,
      actor_id: value(attrs, :actor_id),
      target_user_id: value(attrs, :target_user_id),
      chat_id: value(attrs, :chat_id),
      message_id: value(attrs, :message_id),
      reason: value(attrs, :reason),
      metadata: value(attrs, :metadata) || %{},
      occurred_at: value(attrs, :occurred_at) || DateTime.utc_now()
    }
  end

  defp build_permissions(templates, allowed_keys, template, overrides) do
    case Map.fetch(templates, template) do
      {:ok, base} ->
        {:ok,
         base
         |> Map.merge(take_allowed(overrides, allowed_keys))
         |> take_allowed(allowed_keys)}

      :error ->
        {:error, "Unknown Telegram permission template: #{template}"}
    end
  end

  defp resolve_member_permissions(template) when is_atom(template), do: member_permissions(template)
  defp resolve_member_permissions(permissions) when is_map(permissions), do: {:ok, take_allowed(permissions, @permission_keys)}

  defp resolve_admin_permissions(template) when is_atom(template), do: admin_permissions(template)
  defp resolve_admin_permissions(permissions) when is_map(permissions), do: {:ok, take_allowed(permissions, @admin_permission_keys)}

  defp take_allowed(values, allowed_keys) do
    values
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      atom_key = normalize_key(key)

      if atom_key in allowed_keys and is_boolean(value) do
        Map.put(acc, atom_key, value)
      else
        acc
      end
    end)
  end

  defp normalize_key(key) when is_atom(key), do: key

  defp normalize_key(key) when is_binary(key) do
    (@permission_keys ++ @admin_permission_keys)
    |> Enum.find(key, &(Atom.to_string(&1) == key))
  end

  defp action(method, endpoint, payload) do
    %{method: method, endpoint: endpoint, payload: payload}
  end

  defp put_optional(map, _key, nil), do: map
  defp put_optional(map, key, value), do: Map.put(map, key, value)

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil
end
