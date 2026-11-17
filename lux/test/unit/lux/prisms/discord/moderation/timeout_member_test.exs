defmodule Lux.Prisms.Discord.Moderation.TimeoutMemberTest do
  @moduledoc """
  Test suite for the TimeoutMember module.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.TimeoutMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @timeout_until "2024-12-31T23:59:59Z"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully times out a member" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["communication_disabled_until"] == @timeout_until

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "user" => %{"id" => @user_id},
          "communication_disabled_until" => @timeout_until
        }))
      end)

      assert {:ok, %{
        timed_out: true,
        user_id: @user_id,
        guild_id: @guild_id,
        until: @timeout_until
      }} = TimeoutMember.handler(
        %{guild_id: @guild_id, user_id: @user_id, communication_disabled_until: @timeout_until},
        @agent_ctx
      )
    end

    test "removes timeout with nil" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["communication_disabled_until"] == nil

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "user" => %{"id" => @user_id},
          "communication_disabled_until" => nil
        }))
      end)

      assert {:ok, %{timed_out: true, until: nil}} = TimeoutMember.handler(
        %{guild_id: @guild_id, user_id: @user_id, communication_disabled_until: nil},
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = TimeoutMember.handler(
        %{guild_id: @guild_id, user_id: @user_id, communication_disabled_until: @timeout_until},
        @agent_ctx
      )
    end
  end
end
