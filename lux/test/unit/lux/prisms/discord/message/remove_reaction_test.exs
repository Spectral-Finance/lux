defmodule Lux.Prisms.Discord.Messages.RemoveReactionTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Messages.RemoveReaction

  @channel_id "123456789012345678"
  @message_id "987654321098765432"
  @user_id "222222222222222222"
  @emoji "custom_emoji:123456789"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully removes the bot reaction" do
      encoded_emoji = URI.encode(@emoji)

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"

        assert conn.request_path ==
                 "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/reactions/#{encoded_emoji}/@me"

        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert {:ok,
              %{
                removed: true,
                emoji: @emoji,
                message_id: @message_id,
                channel_id: @channel_id,
                target: "self"
              }} =
               RemoveReaction.handler(
                 %{
                   channel_id: @channel_id,
                   message_id: @message_id,
                   emoji: @emoji,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end

    test "successfully removes a user reaction" do
      encoded_emoji = URI.encode(@emoji)

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"

        assert conn.request_path ==
                 "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/reactions/#{encoded_emoji}/#{@user_id}"

        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert {:ok,
              %{
                removed: true,
                emoji: @emoji,
                message_id: @message_id,
                channel_id: @channel_id,
                target: @user_id
              }} =
               RemoveReaction.handler(
                 %{
                   channel_id: @channel_id,
                   message_id: @message_id,
                   emoji: @emoji,
                   user_id: @user_id,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end

    test "handles Discord API error" do
      encoded_emoji = URI.encode(@emoji)

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"

        assert conn.request_path ==
                 "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/reactions/#{encoded_emoji}/@me"

        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               RemoveReaction.handler(
                 %{
                   channel_id: @channel_id,
                   message_id: @message_id,
                   emoji: @emoji,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = RemoveReaction.view()
      assert prism.input_schema.required == ["channel_id", "message_id", "emoji"]
      assert Map.has_key?(prism.input_schema.properties, :user_id)
    end

    test "validates output schema" do
      prism = RemoveReaction.view()
      assert prism.output_schema.required == ["removed"]
      assert Map.has_key?(prism.output_schema.properties, :target)
    end
  end
end
