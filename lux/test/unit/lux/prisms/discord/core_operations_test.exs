defmodule Lux.Prisms.Discord.CoreOperationsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Channels.SetChannelPermissions
  alias Lux.Prisms.Discord.Channels.UpdateChannel
  alias Lux.Prisms.Discord.Events.CreateScheduledEvent
  alias Lux.Prisms.Discord.Events.DeleteScheduledEvent
  alias Lux.Prisms.Discord.Messages.BulkDeleteMessages
  alias Lux.Prisms.Discord.Moderation.BanMember
  alias Lux.Prisms.Discord.Moderation.TimeoutMember
  alias Lux.Prisms.Discord.Moderation.UnbanMember

  @guild_id "123456789012345678"
  @channel_id "223456789012345678"
  @message_id "323456789012345678"
  @message_id_2 "423456789012345678"
  @user_id "523456789012345678"
  @role_id "623456789012345678"
  @event_id "723456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "bulk deletes messages with audit reason" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/bulk-delete"
      assert Plug.Conn.get_req_header(conn, "x-audit-log-reason") == ["cleanup+spam"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"messages" => [@message_id, @message_id_2]}

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{deleted: true, deleted_count: 2, channel_id: @channel_id}} =
             BulkDeleteMessages.handler(
               %{
                 channel_id: @channel_id,
                 message_ids: [@message_id, @message_id_2],
                 reason: "cleanup spam"
               },
               @agent_ctx
             )
  end

  test "updates channel configuration" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/api/v10/channels/#{@channel_id}"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"name" => "ops", "topic" => "Incident operations"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @channel_id, "name" => "ops"}))
    end)

    assert {:ok, %{updated: true, channel_id: @channel_id, payload: payload}} =
             UpdateChannel.handler(
               %{channel_id: @channel_id, name: "ops", topic: "Incident operations"},
               @agent_ctx
             )

    assert payload == %{name: "ops", topic: "Incident operations"}
  end

  test "sets channel permission overwrites" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/api/v10/channels/#{@channel_id}/permissions/#{@role_id}"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"type" => 0, "allow" => "1024", "deny" => "2048"}

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{updated: true, channel_id: @channel_id, overwrite_id: @role_id}} =
             SetChannelPermissions.handler(
               %{
                 channel_id: @channel_id,
                 overwrite_id: @role_id,
                 overwrite_type: 0,
                 allow: "1024",
                 deny: "2048"
               },
               @agent_ctx
             )
  end

  test "times out a guild member" do
    disabled_until = "2026-05-13T16:30:00Z"

    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"communication_disabled_until" => disabled_until}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"user" => %{"id" => @user_id}}))
    end)

    assert {:ok,
            %{
              timed_out: true,
              guild_id: @guild_id,
              user_id: @user_id,
              communication_disabled_until: ^disabled_until
            }} =
             TimeoutMember.handler(
               %{
                 guild_id: @guild_id,
                 user_id: @user_id,
                 communication_disabled_until: disabled_until
               },
               @agent_ctx
             )
  end

  test "bans a guild member" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"delete_message_seconds" => 3600}

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{banned: true, guild_id: @guild_id, user_id: @user_id}} =
             BanMember.handler(
               %{guild_id: @guild_id, user_id: @user_id, delete_message_seconds: 3600},
               @agent_ctx
             )
  end

  test "unbans a guild member" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{unbanned: true, guild_id: @guild_id, user_id: @user_id}} =
             UnbanMember.handler(%{guild_id: @guild_id, user_id: @user_id}, @agent_ctx)
  end

  test "creates an external scheduled event" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "name" => "Launch Review",
               "scheduled_start_time" => "2026-05-13T17:00:00Z",
               "scheduled_end_time" => "2026-05-13T18:00:00Z",
               "privacy_level" => 2,
               "entity_type" => 3,
               "entity_metadata" => %{"location" => "Discord Stage"},
               "description" => "Release checklist"
             }

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(201, Jason.encode!(%{"id" => @event_id, "name" => "Launch Review"}))
    end)

    assert {:ok,
            %{created: true, guild_id: @guild_id, event_id: @event_id, name: "Launch Review"}} =
             CreateScheduledEvent.handler(
               %{
                 guild_id: @guild_id,
                 name: "Launch Review",
                 scheduled_start_time: "2026-05-13T17:00:00Z",
                 scheduled_end_time: "2026-05-13T18:00:00Z",
                 location: "Discord Stage",
                 description: "Release checklist"
               },
               @agent_ctx
             )
  end

  test "deletes a scheduled event" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{deleted: true, guild_id: @guild_id, event_id: @event_id}} =
             DeleteScheduledEvent.handler(%{guild_id: @guild_id, event_id: @event_id}, @agent_ctx)
  end
end
