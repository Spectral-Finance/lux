defmodule Lux.Prisms.Discord.Messages.BulkDeleteMessagesTest do
  @moduledoc """
  Test suite for the BulkDeleteMessages module.
  These tests verify the prism's ability to:
  - Bulk delete multiple messages from Discord channels
  - Handle Discord API errors appropriately
  - Validate message count constraints (2-100 messages)
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Messages.BulkDeleteMessages

  @channel_id "123456789012345678"
  @message_ids ["111111111111111111", "222222222222222222"]
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully bulk deletes messages" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/bulk-delete"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"messages" => @message_ids}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      result = BulkDeleteMessages.handler(
        %{
          channel_id: @channel_id,
          message_ids: @message_ids,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )

      assert {:ok, %{
        deleted: true,
        channel_id: @channel_id,
        message_count: 2
      }} = result
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/bulk-delete"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = BulkDeleteMessages.handler(
        %{
          channel_id: @channel_id,
          message_ids: @message_ids,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "returns error when message_ids has less than 2 items" do
      assert {:error, "Invalid message_ids format or count (must be 2-100 valid message IDs)"} = BulkDeleteMessages.handler(
        %{
          channel_id: @channel_id,
          message_ids: ["111111111111111111"],
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "returns error when message_ids has more than 100 items" do
      message_ids = for n <- 1..101, do: "12345678901234567#{n}"

      assert {:error, "Invalid message_ids format or count (must be 2-100 valid message IDs)"} = BulkDeleteMessages.handler(
        %{
          channel_id: @channel_id,
          message_ids: message_ids,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = BulkDeleteMessages.view()
      assert prism.input_schema.required == ["channel_id", "message_ids"]
      assert Map.has_key?(prism.input_schema.properties, :channel_id)
      assert Map.has_key?(prism.input_schema.properties, :message_ids)
    end

    test "validates output schema" do
      prism = BulkDeleteMessages.view()
      assert prism.output_schema.required == ["deleted", "channel_id", "message_count"]
      assert Map.has_key?(prism.output_schema.properties, :deleted)
      assert Map.has_key?(prism.output_schema.properties, :channel_id)
      assert Map.has_key?(prism.output_schema.properties, :message_count)
    end
  end
end
