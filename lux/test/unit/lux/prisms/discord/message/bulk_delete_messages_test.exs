defmodule Lux.Prisms.Discord.Messages.BulkDeleteMessagesTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Messages.BulkDeleteMessages

  @channel_id "123456789012345678"
  @message_ids ["111111111111111111", "222222222222222222", "333333333333333333"]
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully bulk-deletes messages" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/bulk-delete"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["messages"] == @message_ids

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{deleted: true, count: 3, channel_id: @channel_id}} =
        BulkDeleteMessages.handler(
          %{channel_id: @channel_id, message_ids: @message_ids, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
        BulkDeleteMessages.handler(
          %{channel_id: @channel_id, message_ids: @message_ids, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "returns error when fewer than 2 message IDs provided" do
      assert {:error, "message_ids must contain between 2 and 100 IDs, got 1"} =
        BulkDeleteMessages.handler(
          %{channel_id: @channel_id, message_ids: ["111111111111111111"]},
          @agent_ctx
        )
    end

    test "returns error when message_ids is missing" do
      assert {:error, "Missing or invalid message_ids"} =
        BulkDeleteMessages.handler(%{channel_id: @channel_id}, @agent_ctx)
    end

    test "returns error when channel_id is missing" do
      assert {:error, "Missing or invalid channel_id"} =
        BulkDeleteMessages.handler(%{message_ids: @message_ids}, @agent_ctx)
    end
  end
end
