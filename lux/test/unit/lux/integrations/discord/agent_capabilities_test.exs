defmodule Lux.Integrations.Discord.AgentCapabilitiesTest do
  use UnitCase, async: true

  alias Lux.Integrations.Discord.AgentCapabilities

  @attrs %{
    guild_id: "123456789012345678",
    channel_id: "234567890123456789",
    member_id: "345678901234567890",
    role_id: "456789012345678901",
    agent_roles: ["moderator"],
    content: "status update"
  }

  test "builds server resource management plans" do
    plan = AgentCapabilities.plan(@attrs)
    operations = plan.server_management.operations

    assert Enum.any?(operations, &(&1.capability == :create_channel))
    assert Enum.any?(operations, &(&1.capability == :leave_server))
    assert Enum.any?(operations, &(&1.capability == :assign_role))
    assert :create_manage_channels in plan.server_management.coverage
    assert :monitor_server_activity in plan.server_management.coverage
  end

  test "builds conversation plans with threads, messages, reactions, and history analysis" do
    plan = AgentCapabilities.plan(@attrs)
    operations = plan.conversation_management.operations

    assert Enum.any?(operations, &(&1.capability == :send_message))
    assert Enum.any?(operations, &(&1.capability == :create_thread))
    assert Enum.any?(operations, &(&1.capability == :react))
    assert Enum.any?(operations, &(&1.capability == :message_history))
    assert :reaction_handling in plan.conversation_management.coverage
  end

  test "builds role and member interaction protocols" do
    plan = AgentCapabilities.plan(@attrs)

    assert :role_hierarchy in plan.role_management.coverage
    assert Enum.any?(plan.role_management.operations, &(&1.capability == :create_role))
    assert Enum.any?(plan.member_interaction.operations, &(&1.capability == :direct_message))
    assert Enum.any?(plan.member_interaction.operations, &(&1.capability == :member_profile))
    assert :user_profiling in plan.member_interaction.coverage
  end

  test "adapts behavior to agent role policies" do
    policy = AgentCapabilities.plan(@attrs).behavior_policy

    refute policy.role_adaptation[:can_manage_roles?]
    assert policy.role_adaptation[:can_moderate?]
    assert policy.role_adaptation[:can_converse?]
    assert "send_message" in policy.allowed_actions
    refute "assign_role" in policy.allowed_actions
  end

  test "accepts string keyed input" do
    plan =
      AgentCapabilities.plan(%{
        "guild_id" => "guild",
        "channel_id" => "channel",
        "member_id" => "member",
        "role_id" => "role",
        "agent_roles" => ["admin"]
      })

    assert plan.behavior_policy.role_adaptation[:can_manage_roles?]
    assert plan.safety.mode == :plan_only
  end

  test "accepts singular agent role and custom atom keyed policies" do
    plan =
      AgentCapabilities.plan(%{
        "agent_role" => "auditor",
        role_policies: %{auditor: [:analyze_history, :send_message]}
      })

    assert plan.behavior_policy.agent_roles == ["auditor"]
    assert plan.behavior_policy.role_adaptation[:can_converse?]
    assert "analyze_history" in plan.behavior_policy.allowed_actions
  end
end
