defmodule Lux.Prisms.Discord.Moderation.TimeoutUserTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.TimeoutUser

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @until "2026-02-24T00:00:00Z"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully applies timeout" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"communication_disabled_until" => @until}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @user_id}))
      end)

      assert {:ok, %{timed_out: true, user_id: @user_id, until: @until}} =
        TimeoutUser.handler(
          %{guild_id: @guild_id, user_id: @user_id, until: @until, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "successfully removes timeout with nil until" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"communication_disabled_until" => nil}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @user_id}))
      end)

      assert {:ok, %{timed_out: true, user_id: @user_id, until: nil}} =
        TimeoutUser.handler(
          %{guild_id: @guild_id, user_id: @user_id, until: nil, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "handles missing permissions error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
        TimeoutUser.handler(
          %{guild_id: @guild_id, user_id: @user_id, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "returns error when guild_id is missing" do
      assert {:error, "Missing or invalid guild_id"} =
        TimeoutUser.handler(%{user_id: @user_id}, @agent_ctx)
    end
  end
end
