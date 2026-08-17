defmodule Lux.Prisms.Discord.Messages.GetMessageTest do
  @moduledoc """
  Test suite for GetMessage prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Messages.GetMessage

  @channel_id "123456789012345678"
  @message_id "111111111111111111"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully retrieves a single message" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @message_id,
          "content" => "Test message",
          "channel_id" => @channel_id,
          "author" => %{"id" => "999999999999999999", "username" => "testuser"}
        }))
      end)

      assert {:ok, %{
        message_id: @message_id,
        content: "Test message",
        channel_id: @channel_id,
        author: %{"id" => "999999999999999999", "username" => "testuser"}
      }} = GetMessage.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end