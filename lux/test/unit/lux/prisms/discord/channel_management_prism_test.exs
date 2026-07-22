defmodule Lux.Prisms.Discord.ChannelManagementPrismTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.ChannelManagementPrism

  @guild_id "12345"
  @channel_id "67890"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "create channel" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/channels"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"name" => "test-channel", "type" => 0}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @channel_id, "name" => "test-channel"}))
      end)

      assert {:ok, %{status: "success", data: %{"id" => @channel_id}}} = ChannelManagementPrism.handler(
        %{action: "create", guild_id: @guild_id, name: "test-channel", type: 0},
        @agent_ctx
      )
    end

    test "update channel" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"name" => "updated"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @channel_id, "name" => "updated"}))
      end)

      assert {:ok, %{status: "success"}} = ChannelManagementPrism.handler(
        %{action: "update", channel_id: @channel_id, name: "updated"},
        @agent_ctx
      )
    end

    test "delete channel" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @channel_id}))
      end)

      assert {:ok, %{status: "success"}} = ChannelManagementPrism.handler(
        %{action: "delete", channel_id: @channel_id},
        @agent_ctx
      )
    end

    test "get channel" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @channel_id}))
      end)

      assert {:ok, %{status: "success", data: %{"id" => @channel_id}}} = ChannelManagementPrism.handler(
        %{action: "get", channel_id: @channel_id},
        @agent_ctx
      )
    end
    test "returns error instead of raising when required params are missing" do
      assert {:error, "action is required"} =
               ChannelManagementPrism.handler(%{}, @agent_ctx)
    end

    test "accepts string-keyed tool input" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @channel_id, "name" => "test-channel"}))
      end)

      assert {:ok, %{status: "success"}} =
               ChannelManagementPrism.handler(
                 %{"action" => "create", "guild_id" => @guild_id, "name" => "test-channel", "type" => 0},
                 @agent_ctx
               )
    end

    test "handles 429 rate limit (using existing Client return shapes)" do
      Req.Test.stub(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"message" => "Rate limit", "retry_after" => 0.05}))
      end)

      assert {:error, {429, "Rate limit"}} =
               ChannelManagementPrism.handler(
                 %{action: "get", channel_id: @channel_id},
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
               ChannelManagementPrism.handler(
                 %{action: "get", channel_id: @channel_id},
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
               ChannelManagementPrism.handler(
                 %{action: "get", channel_id: @channel_id},
                 @agent_ctx
               )
    end
  end
end
