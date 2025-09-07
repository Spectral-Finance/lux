defmodule Lux.Prisms.Discord.Messages.RemoveReactionTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Messages.RemoveReaction

  @channel_id "123456789012345678"
  @message_id "987654321098765432"
  @user_id "111111111111111111"
  @unicode_emoji "👍"
  @custom_emoji "custom_emoji:123456789"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully removes unicode emoji reaction" do
      encoded_emoji = URI.encode(@unicode_emoji)
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/reactions/#{encoded_emoji}/#{@user_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, %{
        removed: true,
        emoji: @unicode_emoji,
        message_id: @message_id,
        channel_id: @channel_id,
        user_id: @user_id
      }} = RemoveReaction.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          user_id: @user_id,
          emoji: @unicode_emoji,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully removes custom emoji reaction" do
      encoded_emoji = URI.encode(@custom_emoji)
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/reactions/#{encoded_emoji}/#{@user_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, %{
        removed: true,
        emoji: @custom_emoji,
        message_id: @message_id,
        channel_id: @channel_id,
        user_id: @user_id
      }} = RemoveReaction.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          user_id: @user_id,
          emoji: @custom_emoji,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      encoded_emoji = URI.encode(@unicode_emoji)
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/reactions/#{encoded_emoji}/#{@user_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = RemoveReaction.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          user_id: @user_id,
          emoji: @unicode_emoji,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = RemoveReaction.view()
      assert prism.input_schema.required == ["channel_id", "message_id", "user_id", "emoji"]
      assert Map.has_key?(prism.input_schema.properties, :channel_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
      assert Map.has_key?(prism.input_schema.properties, :user_id)
      assert Map.has_key?(prism.input_schema.properties, :emoji)
    end

    test "validates output schema" do
      prism = RemoveReaction.view()
      assert prism.output_schema.required == ["removed"]
      assert Map.has_key?(prism.output_schema.properties, :removed)
      assert Map.has_key?(prism.output_schema.properties, :emoji)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :channel_id)
      assert Map.has_key?(prism.output_schema.properties, :user_id)
    end
  end
end
