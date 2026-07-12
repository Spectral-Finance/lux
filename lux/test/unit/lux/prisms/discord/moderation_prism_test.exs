defmodule Lux.Prisms.Discord.ModerationPrismTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.ModerationPrism

  @guild_id "12345"
  @user_id "67890"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "timeout user" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"communication_disabled_until" => "2026-07-05T00:00:00Z"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, %{status: "success"}} = ModerationPrism.handler(
        %{action: "timeout", guild_id: @guild_id, user_id: @user_id, communication_disabled_until: "2026-07-05T00:00:00Z"},
        @agent_ctx
      )
    end

    test "ban user" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"
        assert Plug.Conn.get_req_header(conn, "x-audit-log-reason") == ["spam"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"delete_message_seconds" => 86400}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{status: "success"}} = ModerationPrism.handler(
        %{action: "ban", guild_id: @guild_id, user_id: @user_id, delete_message_days: 1, reason: "spam"},
        @agent_ctx
      )
    end

    test "unban user" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{status: "success"}} = ModerationPrism.handler(
        %{action: "unban", guild_id: @guild_id, user_id: @user_id},
        @agent_ctx
      )
    end

    test "kick user" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{status: "success"}} = ModerationPrism.handler(
        %{action: "kick", guild_id: @guild_id, user_id: @user_id},
        @agent_ctx
      )
    end
    test "returns error instead of raising when required params are missing" do
      assert {:error, "action is required"} =
               ModerationPrism.handler(%{}, @agent_ctx)
    end

    test "accepts string-keyed tool input" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{status: "success"}} =
               ModerationPrism.handler(
                 %{"action" => "kick", "guild_id" => @guild_id, "user_id" => @user_id},
                 @agent_ctx
               )
    end

    test "handles 429 rate limit (using existing Client return shapes)" do
      Req.Test.stub(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"message" => "Rate limit", "retry_after" => 0.05}))
      end)

      assert {:error, {429, "Rate limit", 0.05}} =
               ModerationPrism.handler(
                 %{action: "ban", guild_id: @guild_id, user_id: @user_id},
                 @agent_ctx
               )
    end

    test "handles 400 bad request" do
      Req.Test.stub(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"message" => "Bad Request"}))
      end)

      assert {:error, {400, "Bad Request"}} =
               ModerationPrism.handler(
                 %{action: "ban", guild_id: @guild_id, user_id: @user_id},
                 @agent_ctx
               )
    end

    test "handles 403 forbidden" do
      Req.Test.stub(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Forbidden"}))
      end)

      assert {:error, {403, "Forbidden"}} =
               ModerationPrism.handler(
                 %{action: "ban", guild_id: @guild_id, user_id: @user_id},
                 @agent_ctx
               )
    end
  end
end
