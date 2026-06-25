defmodule Lux.Integrations.Discord.AnalyticsTest do
  @moduledoc """
  Tests for the Discord Analytics integration module.
  """

  use UnitAPICase, async: true

  alias Lux.Integrations.Discord.Analytics

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "get_audit_log/2" do
    test "returns audit log entries on success" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/guild123/audit-logs"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "audit_log_entries" => [
            %{"id" => "1", "action_type" => 1, "target_id" => "123", "user_id" => "456"}
          ],
          "users" => [%{"id" => "456", "username" => "admin"}],
          "integrations" => []
        }))
      end)

      {:ok, result} = Analytics.get_audit_log("guild123", %{plug: {Req.Test, DiscordClientMock}})
      assert length(result["audit_log_entries"]) == 1
      assert length(result["users"]) == 1
    end

    test "returns error on failure" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      {:error, {403, "Missing Permissions"}} =
        Analytics.get_audit_log("guild123", %{plug: {Req.Test, DiscordClientMock}})
    end

    test "passes query parameters correctly" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.query_string =~ "limit=10"
        assert conn.query_string =~ "user_id=user456"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "audit_log_entries" => [],
          "users" => [],
          "integrations" => []
        }))
      end)

      {:ok, _} = Analytics.get_audit_log("guild123", %{
        user_id: "user456",
        limit: 10,
        plug: {Req.Test, DiscordClientMock}
      })
    end
  end

  describe "get_guild_members/2" do
    test "returns member list on success" do
      mock_members = [
        %{"user" => %{"id" => "u1", "username" => "alice"}, "roles" => ["admin"]},
        %{"user" => %{"id" => "u2", "username" => "bob", "bot" => true}, "roles" => []}
      ]

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/guild123/members"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(mock_members))
      end)

      {:ok, members} = Analytics.get_guild_members("guild123", %{plug: {Req.Test, DiscordClientMock}})
      assert length(members) == 2
    end

    test "returns error for unexpected response" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!("unexpected"))
      end)

      {:error, {:unexpected_response, _}} =
        Analytics.get_guild_members("guild123", %{plug: {Req.Test, DiscordClientMock}})
    end
  end

  describe "get_guild/2" do
    test "returns guild info" do
      mock_guild = %{"id" => "guild123", "name" => "Test Server", "member_count" => 500}

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "/api/v10/guilds/guild123"
        assert conn.query_string =~ "with_counts=true"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(mock_guild))
      end)

      {:ok, guild} = Analytics.get_guild("guild123", %{plug: {Req.Test, DiscordClientMock}})
      assert guild["name"] == "Test Server"
      assert guild["member_count"] == 500
    end
  end

  describe "get_guild_channels/2" do
    test "returns channel list" do
      mock_channels = [
        %{"id" => "ch1", "name" => "general", "type" => 0},
        %{"id" => "ch2", "name" => "voice-1", "type" => 2}
      ]

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/guild123/channels"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(mock_channels))
      end)

      {:ok, channels} = Analytics.get_guild_channels("guild123", %{plug: {Req.Test, DiscordClientMock}})
      assert length(channels) == 2
    end
  end

  describe "get_guild_bans/2" do
    test "returns ban list" do
      mock_bans = [%{"user" => %{"id" => "u1"}, "reason" => "spam"}]

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/guild123/bans"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(mock_bans))
      end)

      {:ok, bans} = Analytics.get_guild_bans("guild123", %{plug: {Req.Test, DiscordClientMock}})
      assert length(bans) == 1
    end
  end

  describe "analyze_activity/1" do
    test "computes activity metrics from events" do
      events = [
        %{type: :message, user_id: "u1", channel_id: "c1", timestamp: ~U[2026-01-01 14:00:00Z], metadata: %{}},
        %{type: :message, user_id: "u1", channel_id: "c1", timestamp: ~U[2026-01-01 14:30:00Z], metadata: %{}},
        %{type: :voice, user_id: "u2", channel_id: "vc1", timestamp: ~U[2026-01-01 15:00:00Z], metadata: %{action: :join}},
        %{type: :message, user_id: "u2", channel_id: "c2", timestamp: ~U[2026-01-01 14:00:00Z], metadata: %{}},
        %{type: :webhook, user_id: "u3", channel_id: "c1", timestamp: ~U[2026-01-01 16:00:00Z], metadata: %{}}
      ]

      result = Analytics.analyze_activity(events)

      assert result.total_events == 5
      assert result.by_type[:message] == 3
      assert result.by_type[:voice] == 1
      assert result.by_type[:webhook] == 1
      assert result.by_user["u1"] == 2
      assert result.by_user["u2"] == 2
      assert result.by_channel["c1"] == 3
      assert result.peak_hour == 14
      assert result.most_active_channel == "c1"
    end

    test "handles empty event list" do
      result = Analytics.analyze_activity([])
      assert result.total_events == 0
      assert result.by_type == %{}
      assert result.peak_hour == nil
      assert result.most_active_user == nil
      assert result.most_active_channel == nil
    end

    test "handles events with nil timestamps" do
      events = [
        %{type: :message, user_id: "u1", channel_id: "c1", timestamp: nil, metadata: %{}},
        %{type: :message, user_id: "u1", channel_id: "c1", timestamp: ~U[2026-01-01 14:00:00Z], metadata: %{}}
      ]

      result = Analytics.analyze_activity(events)
      assert result.total_events == 2
      assert result.by_hour == %{14 => 1}
    end
  end

  describe "member_stats/1" do
    test "computes member statistics" do
      members = [
        %{"user" => %{"id" => "u1"}, "roles" => ["admin"]},
        %{"user" => %{"id" => "u2"}, "roles" => ["member"]},
        %{"user" => %{"id" => "u3", "bot" => true}, "roles" => []},
        %{"user" => %{"id" => "u4", "bot" => true}, "roles" => []}
      ]

      result = Analytics.member_stats(members)
      assert result.total == 4
      assert result.humans == 2
      assert result.bots == 2
      assert result.bot_ratio == 0.5
    end

    test "handles empty member list" do
      result = Analytics.member_stats([])
      assert result.total == 0
      assert result.humans == 0
      assert result.bots == 0
      assert result.bot_ratio == 0.0
    end
  end

  describe "channel_usage/1" do
    test "computes channel usage from message events" do
      events = [
        %{type: :message, user_id: "u1", channel_id: "c1", timestamp: ~U[2026-01-01 14:00:00Z], metadata: %{}},
        %{type: :message, user_id: "u2", channel_id: "c1", timestamp: ~U[2026-01-01 15:00:00Z], metadata: %{}},
        %{type: :message, user_id: "u1", channel_id: "c1", timestamp: ~U[2026-01-01 14:30:00Z], metadata: %{}},
        %{type: :voice, user_id: "u1", channel_id: "vc1", timestamp: ~U[2026-01-01 14:00:00Z], metadata: %{}},
        %{type: :message, user_id: "u1", channel_id: "c2", timestamp: ~U[2026-01-01 16:00:00Z], metadata: %{}}
      ]

      result = Analytics.channel_usage(events)
      assert result.total_messages == 4
      assert result.channels["c1"].count == 3
      assert result.channels["c1"].unique_users == 2
      assert result.channels["c2"].count == 1
    end
  end

  describe "voice_analytics/1" do
    test "computes voice analytics from voice events" do
      events = [
        %{type: :voice, user_id: "u1", channel_id: "vc1", timestamp: ~U[2026-01-01 14:00:00Z], metadata: %{action: :join}},
        %{type: :voice, user_id: "u2", channel_id: "vc1", timestamp: ~U[2026-01-01 14:05:00Z], metadata: %{action: :join}},
        %{type: :voice, user_id: "u1", channel_id: "vc1", timestamp: ~U[2026-01-01 15:00:00Z], metadata: %{action: :leave}},
        %{type: :voice, user_id: "u2", channel_id: "vc2", timestamp: ~U[2026-01-01 16:00:00Z], metadata: %{action: :join}},
        %{type: :message, user_id: "u1", channel_id: "c1", timestamp: ~U[2026-01-01 14:00:00Z], metadata: %{}}
      ]

      result = Analytics.voice_analytics(events)
      assert result.total_voice_events == 4
      assert result.join_count == 3
      assert result.leave_count == 1
      assert result.unique_users == 2
      assert result.channels["vc1"].joins == 2
      assert result.channels["vc1"].leaves == 1
      assert result.channels["vc2"].joins == 1
    end

    test "handles empty voice events" do
      result = Analytics.voice_analytics([])
      assert result.total_voice_events == 0
      assert result.join_count == 0
      assert result.leave_count == 0
      assert result.unique_users == 0
      assert result.channels == %{}
    end
  end
end
