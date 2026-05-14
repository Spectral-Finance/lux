defmodule Lux.Integrations.Discord.AgentCapabilities do
  @moduledoc """
  Agent-oriented Discord capability planning.

  The module builds deterministic operation plans for server resources,
  conversations, roles, and member interactions. It does not execute Discord
  requests directly; transport layers can review and run the returned plans.
  """

  @default_policy %{
    "admin" => [
      "create_channel",
      "delete_channel",
      "manage_roles",
      "assign_role",
      "create_thread",
      "send_message",
      "react",
      "direct_message",
      "timeout_member",
      "analyze_history"
    ],
    "moderator" => [
      "create_thread",
      "send_message",
      "react",
      "timeout_member",
      "analyze_history"
    ],
    "member" => [
      "send_message",
      "react",
      "create_thread"
    ]
  }

  @doc "Builds a full Discord agent capability plan."
  @spec plan(map()) :: map()
  def plan(attrs \\ %{}) when is_map(attrs) do
    attrs = normalize_keys(attrs)
    guild_id = Map.get(attrs, :guild_id, "GUILD_ID")
    channel_id = Map.get(attrs, :channel_id, "CHANNEL_ID")
    member_id = Map.get(attrs, :member_id, "MEMBER_ID")
    role_id = Map.get(attrs, :role_id, "ROLE_ID")
    roles = agent_roles(attrs)
    policies = Map.merge(@default_policy, normalize_policies(Map.get(attrs, :role_policies, %{})))

    %{
      server_management:
        server_management(%{
          guild_id: guild_id,
          channel_name: Map.get(attrs, :channel_name, "agent-ops"),
          role_name: Map.get(attrs, :role_name, "Agent Operator"),
          role_id: role_id,
          member_id: member_id
        }),
      conversation_management:
        conversation_management(%{
          channel_id: channel_id,
          message_id: Map.get(attrs, :message_id, "MESSAGE_ID"),
          thread_name: Map.get(attrs, :thread_name, "agent-thread"),
          content: Map.get(attrs, :content, "Agent update"),
          emoji: Map.get(attrs, :emoji, "✅")
        }),
      role_management:
        role_management(%{
          guild_id: guild_id,
          member_id: member_id,
          role_id: role_id,
          role_name: Map.get(attrs, :role_name, "Agent Operator"),
          desired_permissions:
            list(attrs, :desired_permissions, ["VIEW_CHANNEL", "SEND_MESSAGES"])
        }),
      member_interaction:
        member_interaction(%{
          guild_id: guild_id,
          member_id: member_id,
          dm_content: Map.get(attrs, :dm_content, "Agent follow-up"),
          timeout_minutes: Map.get(attrs, :timeout_minutes, 15)
        }),
      behavior_policy: behavior_policy(roles, policies),
      safety: %{
        mode: :plan_only,
        requires_discord_bot_token: true,
        requires_transport_review: true,
        notes: [
          "Plans intentionally do not execute live Discord requests.",
          "Review permissions and audit reason before dispatching moderation or role operations."
        ]
      }
    }
  end

  @doc "Builds server resource management operations."
  @spec server_management(map()) :: map()
  def server_management(attrs) do
    guild_id = Map.fetch!(attrs, :guild_id)
    channel_name = Map.fetch!(attrs, :channel_name)
    role_name = Map.fetch!(attrs, :role_name)
    role_id = Map.fetch!(attrs, :role_id)
    member_id = Map.fetch!(attrs, :member_id)

    %{
      operations: [
        request(
          :post,
          "/guilds/#{guild_id}/channels",
          %{name: channel_name, type: 0},
          :create_channel
        ),
        request(:delete, "/users/@me/guilds/#{guild_id}", %{}, :leave_server),
        request(:post, "/guilds/#{guild_id}/roles", %{name: role_name}, :create_role),
        request(
          :put,
          "/guilds/#{guild_id}/members/#{member_id}/roles/#{role_id}",
          %{},
          :assign_role
        ),
        request(
          :put,
          "/channels/CHANNEL_ID/permissions/#{role_id}",
          permission_overwrite(),
          :manage_permissions
        )
      ],
      coverage: [
        :join_leave_servers,
        :create_manage_channels,
        :manage_roles_and_permissions,
        :monitor_server_activity
      ],
      monitoring: %{
        recommended_events: [
          "GUILD_CREATE",
          "GUILD_UPDATE",
          "CHANNEL_CREATE",
          "GUILD_MEMBER_UPDATE"
        ],
        summary_keys: [:guild_id, :channel_count, :role_count, :member_count]
      }
    }
  end

  @doc "Builds conversation, thread, message, and reaction operations."
  @spec conversation_management(map()) :: map()
  def conversation_management(attrs) do
    channel_id = Map.fetch!(attrs, :channel_id)
    message_id = Map.fetch!(attrs, :message_id)
    thread_name = Map.fetch!(attrs, :thread_name)
    content = Map.fetch!(attrs, :content)
    emoji = Map.fetch!(attrs, :emoji)

    %{
      operations: [
        request(:post, "/channels/#{channel_id}/messages", %{content: content}, :send_message),
        request(
          :post,
          "/channels/#{channel_id}/messages/#{message_id}/threads",
          %{name: thread_name},
          :create_thread
        ),
        request(
          :patch,
          "/channels/#{channel_id}/messages/#{message_id}",
          %{content: content},
          :edit_message
        ),
        request(
          :put,
          "/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/@me",
          %{},
          :react
        ),
        request(:get, "/channels/#{channel_id}/messages", %{limit: 50}, :message_history)
      ],
      history_analysis: %{
        signals: [:author_frequency, :mention_frequency, :thread_participation, :reaction_totals],
        retention_policy: :summaries_only
      },
      coverage: [
        :thread_management,
        :message_management,
        :reaction_handling,
        :message_history_analysis
      ]
    }
  end

  @doc "Builds role assignment and hierarchy plans."
  @spec role_management(map()) :: map()
  def role_management(attrs) do
    guild_id = Map.fetch!(attrs, :guild_id)
    member_id = Map.fetch!(attrs, :member_id)
    role_id = Map.fetch!(attrs, :role_id)
    role_name = Map.fetch!(attrs, :role_name)
    permissions = Map.fetch!(attrs, :desired_permissions)

    %{
      operations: [
        request(
          :post,
          "/guilds/#{guild_id}/roles",
          %{name: role_name, permissions: permissions},
          :create_role
        ),
        request(:patch, "/guilds/#{guild_id}/roles/#{role_id}", %{name: role_name}, :update_role),
        request(
          :put,
          "/guilds/#{guild_id}/members/#{member_id}/roles/#{role_id}",
          %{},
          :assign_role
        ),
        request(
          :delete,
          "/guilds/#{guild_id}/members/#{member_id}/roles/#{role_id}",
          %{},
          :remove_role
        )
      ],
      hierarchy: %{
        enforce_bot_role_above_target: true,
        deny_managed_role_edits: true,
        deny_owner_or_admin_escalation: true
      },
      coverage: [:role_assignment, :permission_management, :role_hierarchy, :custom_role_creation]
    }
  end

  @doc "Builds direct member interaction and activity monitoring plans."
  @spec member_interaction(map()) :: map()
  def member_interaction(attrs) do
    guild_id = Map.fetch!(attrs, :guild_id)
    member_id = Map.fetch!(attrs, :member_id)
    dm_content = Map.fetch!(attrs, :dm_content)
    timeout_minutes = Map.fetch!(attrs, :timeout_minutes)

    %{
      operations: [
        request(:post, "/users/@me/channels", %{recipient_id: member_id}, :open_direct_message),
        request(
          :post,
          "/channels/DM_CHANNEL_ID/messages",
          %{content: dm_content},
          :direct_message
        ),
        request(
          :patch,
          "/guilds/#{guild_id}/members/#{member_id}",
          timeout_body(timeout_minutes),
          :timeout_member
        ),
        request(:get, "/guilds/#{guild_id}/members/#{member_id}", %{}, :member_profile)
      ],
      activity_monitoring: %{
        signals: [:last_message_at, :thread_count, :reaction_count, :moderation_events],
        profile_fields: [:id, :username, :roles, :joined_at, :communication_disabled_until]
      },
      coverage: [:direct_messaging, :member_management, :activity_monitoring, :user_profiling]
    }
  end

  @doc "Computes role-based behavior adaptation for an agent."
  @spec behavior_policy([String.t()], map()) :: map()
  def behavior_policy(agent_roles, policies) when is_list(agent_roles) and is_map(policies) do
    allowed =
      agent_roles
      |> Enum.flat_map(&Map.get(policies, to_string(&1), []))
      |> Enum.uniq()
      |> Enum.sort()

    %{
      agent_roles: agent_roles,
      allowed_actions: allowed,
      blocked_by_default: true,
      require_audit_reason_for: ["assign_role", "remove_role", "timeout_member", "delete_channel"],
      role_adaptation: %{
        can_moderate?: Enum.any?(allowed, &(&1 in ["timeout_member", "delete_channel"])),
        can_manage_roles?: "manage_roles" in allowed or "assign_role" in allowed,
        can_converse?: "send_message" in allowed
      }
    }
  end

  defp request(method, path, body, capability) do
    %{
      capability: capability,
      method: method,
      path: path,
      body: body,
      required_review:
        capability in [:assign_role, :remove_role, :timeout_member, :delete_channel]
    }
  end

  defp permission_overwrite do
    %{
      type: 0,
      allow: ["VIEW_CHANNEL", "SEND_MESSAGES"],
      deny: []
    }
  end

  defp timeout_body(minutes) do
    %{
      communication_disabled_until: %{
        relative_minutes: minutes,
        transport_should_convert_to_iso8601: true
      }
    }
  end

  defp normalize_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {known_key(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp known_key("guild_id"), do: :guild_id
  defp known_key("channel_id"), do: :channel_id
  defp known_key("member_id"), do: :member_id
  defp known_key("role_id"), do: :role_id
  defp known_key("agent_role"), do: :agent_role
  defp known_key("agent_roles"), do: :agent_roles
  defp known_key("role_policies"), do: :role_policies
  defp known_key("channel_name"), do: :channel_name
  defp known_key("role_name"), do: :role_name
  defp known_key("thread_name"), do: :thread_name
  defp known_key("content"), do: :content
  defp known_key("emoji"), do: :emoji
  defp known_key("dm_content"), do: :dm_content
  defp known_key("timeout_minutes"), do: :timeout_minutes
  defp known_key("desired_permissions"), do: :desired_permissions
  defp known_key(key), do: key

  defp list(attrs, key, default) do
    case Map.get(attrs, key, default) do
      value when is_list(value) -> Enum.map(value, &to_string/1)
      value when is_binary(value) -> [value]
      _ -> default
    end
  end

  defp agent_roles(attrs) do
    if Map.has_key?(attrs, :agent_roles) do
      list(attrs, :agent_roles, ["member"])
    else
      list(attrs, :agent_role, ["member"])
    end
  end

  defp normalize_policies(policies) when is_map(policies) do
    Map.new(policies, fn {role, actions} -> {to_string(role), to_string_list(actions)} end)
  end

  defp normalize_policies(_), do: %{}

  defp to_string_list(actions) when is_list(actions), do: Enum.map(actions, &to_string/1)
  defp to_string_list(action) when is_binary(action), do: [action]
  defp to_string_list(_), do: []
end
