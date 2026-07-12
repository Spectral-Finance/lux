defmodule Lux.Prisms.Discord.EventHandlingPrismTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.EventHandlingPrism

  @guild_id "12345"
  @event_id "67890"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "create event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"name" => "test-event", "privacy_level" => 2}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @event_id, "name" => "test-event"}))
      end)

      assert {:ok, %{status: "success", data: %{"id" => @event_id}}} = EventHandlingPrism.handler(
        %{action: "create", guild_id: @guild_id, name: "test-event", privacy_level: 2},
        @agent_ctx
      )
    end

    test "update event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"name" => "updated"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @event_id, "name" => "updated"}))
      end)

      assert {:ok, %{status: "success"}} = EventHandlingPrism.handler(
        %{action: "update", guild_id: @guild_id, event_id: @event_id, name: "updated"},
        @agent_ctx
      )
    end

    test "delete event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{status: "success"}} = EventHandlingPrism.handler(
        %{action: "delete", guild_id: @guild_id, event_id: @event_id},
        @agent_ctx
      )
    end

    test "list events" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([%{"id" => @event_id}]))
      end)

      assert {:ok, %{status: "success", data: %{events: [%{"id" => @event_id}]}}} = EventHandlingPrism.handler(
        %{action: "list", guild_id: @guild_id},
        @agent_ctx
      )
    end
    test "returns error instead of raising when required params are missing" do
      assert {:error, "action is required"} =
               EventHandlingPrism.handler(%{}, @agent_ctx)
    end

    test "accepts string-keyed tool input" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @event_id, "name" => "test-event"}))
      end)

      assert {:ok, %{status: "success"}} =
               EventHandlingPrism.handler(
                 %{"action" => "create", "guild_id" => @guild_id, "name" => "test-event", "privacy_level" => 2},
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
               EventHandlingPrism.handler(
                 %{action: "list", guild_id: @guild_id},
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
               EventHandlingPrism.handler(
                 %{action: "list", guild_id: @guild_id},
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
               EventHandlingPrism.handler(
                 %{action: "list", guild_id: @guild_id},
                 @agent_ctx
               )
    end
  end
end
