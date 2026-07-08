defmodule Lux.Prisms.Discord.Messages.EditMessageTest do
  @moduledoc """
  Test suite for the EditMessagePrism module.

  These tests verify the prism's ability to:
  - Edit messages in Discord channels
  - Handle Discord API errors appropriately
  - Validate input/output schemas

  The tests use the Discord API client mock to simulate API interactions and verify:
  - Correct HTTP method (PATCH) is used
  - Proper URL construction
  - Authorization header presence
  - Response handling for both success and error cases
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Messages.EditMessage

  @channel_id "123456789012345678"
  @message_id "987654321098765432"
  @content "Updated message content"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully edits a message" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"content" => @content}

        # Discord API returns 204 No Content on successful edit
        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert {:ok, %{edited: true}} = EditMessage.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          content: @content
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = EditMessage.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          content: @content
        },
        @agent_ctx
      )
    end
  end
end
