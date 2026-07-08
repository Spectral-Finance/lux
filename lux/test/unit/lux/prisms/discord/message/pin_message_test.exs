defmodule Lux.Prisms.Discord.Messages.PinMessageTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Messages.PinMessage

  @channel_id "123456789012345678"
  @message_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully pins a message" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/pins/#{@message_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, %{pinned: true}} = PinMessage.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/pins/#{@message_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = PinMessage.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = PinMessage.view()
      assert prism.input_schema.required == ["channel_id", "message_id"]
      assert Map.has_key?(prism.input_schema.properties, :channel_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
    end

    test "validates output schema" do
      prism = PinMessage.view()
      assert prism.output_schema.required == ["pinned"]
      assert Map.has_key?(prism.output_schema.properties, :pinned)
    end
  end
end
