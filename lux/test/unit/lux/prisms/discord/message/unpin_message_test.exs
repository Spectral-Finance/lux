defmodule Lux.Prisms.Discord.Messages.UnpinMessageTest do
  @moduledoc """
  Test suite for the UnpinMessage module.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Messages.UnpinMessage

  @channel_id "123456789012345678"
  @message_id "111111111111111111"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully unpins a message" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/pins/#{@message_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{
        unpinned: true,
        message_id: @message_id,
        channel_id: @channel_id
      }} = UnpinMessage.handler(
        %{channel_id: @channel_id, message_id: @message_id},
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/pins/#{@message_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Message"
        }))
      end)

      assert {:error, {404, "Unknown Message"}} = UnpinMessage.handler(
        %{channel_id: @channel_id, message_id: @message_id},
        @agent_ctx
      )
    end

    test "validates missing message_id" do
      assert {:error, "Missing or invalid message_id"} =
        UnpinMessage.handler(%{channel_id: @channel_id}, @agent_ctx)
    end
  end
end
