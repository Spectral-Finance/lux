defmodule Lux.Prisms.Discord.Messages.UnpinMessageTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Messages.UnpinMessage

  @channel_id "123456789012345678"
  @message_id "987654321098765432"
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
        |> Plug.Conn.send_resp(204, Jason.encode!(%{}))
      end)

      assert {:ok,
              %{
                unpinned: true,
                message_id: @message_id,
                channel_id: @channel_id
              }} =
               UnpinMessage.handler(
                 %{
                   channel_id: @channel_id,
                   message_id: @message_id,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/pins/#{@message_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               UnpinMessage.handler(
                 %{
                   channel_id: @channel_id,
                   message_id: @message_id,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates schemas" do
      prism = UnpinMessage.view()
      assert prism.input_schema.required == ["channel_id", "message_id"]
      assert prism.output_schema.required == ["unpinned"]
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :channel_id)
    end
  end
end
