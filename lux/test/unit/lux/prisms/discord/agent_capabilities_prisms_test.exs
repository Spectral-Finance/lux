defmodule Lux.Prisms.Discord.AgentCapabilitiesPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Discord.ServerManagementPrism
  alias Lux.Prisms.Discord.ConversationPrism
  alias Lux.Prisms.Discord.RoleManagementPrism
  alias Lux.Prisms.Discord.MemberInteractionPrism

  describe "ServerManagementPrism" do
    test "fetches guild details" do
      {:ok, result} =
        ServerManagementPrism.handler(
          %{"action" => "get_guild", "guild_id" => "123456789"},
          %{}
        )

      assert result.status == "ok"
      assert result.action == "get_guild"
      assert result.guild_id == "123456789"
      assert is_map(result.data)
    end

    test "monitors server activity" do
      {:ok, result} =
        ServerManagementPrism.handler(
          %{"action" => "monitor_activity", "guild_id" => "123456789"},
          %{}
        )

      assert result.status == "healthy"
      assert result.data.active_members > 0
    end
  end

  describe "ConversationPrism" do
    test "fetches conversation history" do
      {:ok, result} =
        ConversationPrism.handler(
          %{"action" => "fetch_history", "channel_id" => "987654321"},
          %{}
        )

      assert result.status == "ok"
      assert result.action == "fetch_history"
      assert is_list(result.result)
    end

    test "creates thread" do
      {:ok, result} =
        ConversationPrism.handler(
          %{
            "action" => "create_thread",
            "channel_id" => "987654321",
            "thread_name" => "Agent Triage"
          },
          %{}
        )

      assert result.status == "created"
      assert result.result.name == "Agent Triage"
    end

    test "analyzes conversation flow" do
      {:ok, result} =
        ConversationPrism.handler(
          %{"action" => "analyze_flow", "channel_id" => "987654321"},
          %{}
        )

      assert result.status == "ok"
      assert result.result.sentiment == "positive"
      assert is_list(result.result.topic_tags)
    end
  end

  describe "RoleManagementPrism" do
    test "lists guild roles" do
      {:ok, result} =
        RoleManagementPrism.handler(
          %{"action" => "list_roles", "guild_id" => "123456789"},
          %{}
        )

      assert result.status == "ok"
      assert is_list(result.result)
    end

    test "creates a new role" do
      {:ok, result} =
        RoleManagementPrism.handler(
          %{
            "action" => "create_role",
            "guild_id" => "123456789",
            "role_name" => "DeFi Specialist"
          },
          %{}
        )

      assert result.status == "created"
      assert result.result.name == "DeFi Specialist"
    end

    test "assigns role to member" do
      {:ok, result} =
        RoleManagementPrism.handler(
          %{
            "action" => "assign_role",
            "guild_id" => "123456789",
            "user_id" => "555",
            "role_id" => "666"
          },
          %{}
        )

      assert result.status == "assigned"
    end
  end

  describe "MemberInteractionPrism" do
    test "gets member profile" do
      {:ok, result} =
        MemberInteractionPrism.handler(
          %{"action" => "get_member", "user_id" => "555"},
          %{}
        )

      assert result.status == "ok"
      assert result.user_id == "555"
      assert is_map(result.result)
    end

    test "sends direct message" do
      {:ok, result} =
        MemberInteractionPrism.handler(
          %{
            "action" => "send_dm",
            "user_id" => "555",
            "message" => "Welcome to the Discord server!"
          },
          %{}
        )

      assert result.status == "delivered"
      assert result.result.sent == true
    end

    test "applies member timeout" do
      {:ok, result} =
        MemberInteractionPrism.handler(
          %{
            "action" => "timeout_member",
            "user_id" => "555",
            "timeout_seconds" => 60
          },
          %{}
        )

      assert result.status == "timed_out"
    end
  end
end
