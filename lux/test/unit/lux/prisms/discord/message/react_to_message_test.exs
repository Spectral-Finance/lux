defmodule Lux.Prisms.Discord.Messages.ReactToMessageTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Messages.ReactToMessage

  @channel_id "123456789012345678"
  @message_id "987654321098765432"
  @unicode_emoji "👍"
  @custom_emoji "custom_emoji:123456789"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully adds unicode emoji reaction" do
      encoded_emoji = URI.encode(@unicode_emoji)
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/reactions/#{encoded_emoji}/@me"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, %{
        reacted: true,
        emoji: @unicode_emoji,
        message_id: @message_id,
        channel_id: @channel_id
      }} = ReactToMessage.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          emoji: @unicode_emoji,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully adds custom emoji reaction" do
      encoded_emoji = URI.encode(@custom_emoji)
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/reactions/#{encoded_emoji}/@me"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, %{
        reacted: true,
        emoji: @custom_emoji,
        message_id: @message_id,
        channel_id: @channel_id
      }} = ReactToMessage.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          emoji: @custom_emoji,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      encoded_emoji = URI.encode(@unicode_emoji)
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/reactions/#{encoded_emoji}/@me"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = ReactToMessage.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          emoji: @unicode_emoji,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = ReactToMessage.view()
      assert prism.input_schema.required == ["channel_id", "message_id", "emoji"]
      assert Map.has_key?(prism.input_schema.properties, :channel_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
      assert Map.has_key?(prism.input_schema.properties, :emoji)
    end

    test "validates output schema" do
      prism = ReactToMessage.view()
      assert prism.output_schema.required == ["reacted"]
      assert Map.has_key?(prism.output_schema.properties, :reacted)
      assert Map.has_key?(prism.output_schema.properties, :emoji)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :channel_id)
    end
  end
end
