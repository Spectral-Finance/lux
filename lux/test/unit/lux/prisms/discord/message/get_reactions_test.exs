defmodule Lux.Prisms.Discord.Messages.GetReactionsTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Messages.GetReactions

  @channel_id "123456789012345678"
  @message_id "987654321098765432"
  @after_user_id "111111111111111111"
  @emoji "custom_emoji:123456789"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully lists reaction users with default limit" do
      encoded_emoji = URI.encode(@emoji)

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"

        assert conn.request_path ==
                 "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/reactions/#{encoded_emoji}"

        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        query = URI.decode_query(conn.query_string)
        assert query["limit"] == "25"
        refute Map.has_key?(query, "after")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!([
            %{
              "id" => "222222222222222222",
              "username" => "tester",
              "discriminator" => "0001",
              "global_name" => "Test User"
            }
          ])
        )
      end)

      assert {:ok,
              %{
                users: [user],
                count: 1,
                emoji: @emoji,
                message_id: @message_id,
                channel_id: @channel_id
              }} =
               GetReactions.handler(
                 %{
                   channel_id: @channel_id,
                   message_id: @message_id,
                   emoji: @emoji,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )

      assert user.id == "222222222222222222"
      assert user.username == "tester"
      assert user.global_name == "Test User"
      assert user.bot == false
    end

    test "successfully lists reaction users with pagination" do
      encoded_emoji = URI.encode(@emoji)

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"

        assert conn.request_path ==
                 "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/reactions/#{encoded_emoji}"

        query = URI.decode_query(conn.query_string)
        assert query["limit"] == "50"
        assert query["after"] == @after_user_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!([
            %{
              "id" => "333333333333333333",
              "username" => "bot-user",
              "discriminator" => "0000",
              "bot" => true
            }
          ])
        )
      end)

      assert {:ok, %{users: [user], count: 1}} =
               GetReactions.handler(
                 %{
                   channel_id: @channel_id,
                   message_id: @message_id,
                   emoji: @emoji,
                   limit: 50,
                   after: @after_user_id,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )

      assert user.id == "333333333333333333"
      assert user.bot == true
    end

    test "handles Discord API error" do
      encoded_emoji = URI.encode(@emoji)

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"

        assert conn.request_path ==
                 "/api/v10/channels/#{@channel_id}/messages/#{@message_id}/reactions/#{encoded_emoji}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               GetReactions.handler(
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
      prism = GetReactions.view()
      assert prism.input_schema.required == ["channel_id", "message_id", "emoji"]
      assert prism.input_schema.properties.limit.default == 25
      assert Map.has_key?(prism.input_schema.properties, :after)
    end

    test "validates output schema" do
      prism = GetReactions.view()
      assert prism.output_schema.required == ["users", "count"]
      assert Map.has_key?(prism.output_schema.properties, :emoji)
    end
  end
end
