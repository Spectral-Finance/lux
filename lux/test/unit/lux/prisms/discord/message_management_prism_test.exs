defmodule Lux.Prisms.Discord.MessageManagementPrismTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.MessageManagementPrism

  @channel_id "1234567890"
  @message_id "9876543210"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "create message" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"content" => "hello"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @message_id, "content" => "hello"}))
      end)

      assert {:ok, %{status: "success", data: %{"id" => @message_id}}} = MessageManagementPrism.handler(
        %{action: "create", channel_id: @channel_id, content: "hello"},
        @agent_ctx
      )
    end

    test "edit message" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"content" => "updated"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @message_id, "content" => "updated"}))
      end)

      assert {:ok, %{status: "success"}} = MessageManagementPrism.handler(
        %{action: "edit", channel_id: @channel_id, message_id: @message_id, content: "updated"},
        @agent_ctx
      )
    end

    test "delete message" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{status: "success"}} = MessageManagementPrism.handler(
        %{action: "delete", channel_id: @channel_id, message_id: @message_id},
        @agent_ctx
      )
    end

    test "bulk delete messages" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/bulk-delete"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"messages" => [@message_id, "111"]}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{status: "success"}} = MessageManagementPrism.handler(
        %{action: "bulk_delete", channel_id: @channel_id, message_ids: [@message_id, "111"]},
        @agent_ctx
      )
    end

    test "fetch history" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages"
        assert conn.query_string == "limit=10"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([%{"id" => @message_id}]))
      end)

      assert {:ok, %{status: "success", data: %{messages: [%{"id" => @message_id}]}}} = MessageManagementPrism.handler(
        %{action: "history", channel_id: @channel_id, limit: 10},
        @agent_ctx
      )
    end
    test "returns error instead of raising when required params are missing" do
      assert {:error, "channel_id is required"} =
               MessageManagementPrism.handler(%{action: "create", content: "hello"}, @agent_ctx)
    end

    test "accepts string-keyed tool input" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @message_id, "content" => "hello"}))
      end)

      assert {:ok, %{status: "success"}} =
               MessageManagementPrism.handler(
                 %{"action" => "create", "channel_id" => @channel_id, "content" => "hello"},
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
               MessageManagementPrism.handler(
                 %{action: "history", channel_id: @channel_id, limit: 5},
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
               MessageManagementPrism.handler(
                 %{action: "history", channel_id: @channel_id, limit: 5},
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
               MessageManagementPrism.handler(
                 %{action: "history", channel_id: @channel_id, limit: 5},
                 @agent_ctx
               )
    end
  end
end
