defmodule Lux.Lenses.Discord.Messages.ListMessagesTest do
  @moduledoc """
  Test suite for the ListMessages module.
  These tests verify the lens's ability to:
  - List messages from a Discord channel
  - Handle pagination parameters
  - Process Discord API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Messages.ListMessages

  @channel_id "123456789012345678"
  @message_id "111111111111111111"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists messages with default parameters" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        # Verify only channel_id is present in the query string
        query = URI.decode_query(conn.query_string)
        assert Map.keys(query) == ["channel_id"]
        assert query["channel_id"] == @channel_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "id" => @message_id,
            "content" => "First message",
            "author" => %{
              "id" => "222222222222222222",
              "username" => "TestUser1"
            }
          },
          %{
            "id" => "333333333333333333",
            "content" => "Second message",
            "author" => %{
              "id" => "444444444444444444",
              "username" => "TestUser2"
            }
          }
        ]))
      end)

      assert {:ok, messages} = ListMessages.focus(%{
        channel_id: @channel_id
      }, %{})

      assert length(messages) == 2
      [first, second] = messages

      assert first.content == "First message"
      assert first.author.username == "TestUser1"
      assert second.content == "Second message"
      assert second.author.username == "TestUser2"
    end

    test "successfully lists messages with pagination parameters" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages"

        # Verify pagination parameters
        query = URI.decode_query(conn.query_string)
        assert query["limit"] == "25"
        assert query["before"] == @message_id
        assert query["channel_id"] == @channel_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "id" => "222222222222222222",
            "content" => "Previous message",
            "author" => %{
              "id" => "333333333333333333",
              "username" => "TestUser"
            }
          }
        ]))
      end)

      assert {:ok, messages} = ListMessages.focus(%{
        channel_id: @channel_id,
        limit: 25,
        before: @message_id
      }, %{})

      assert length(messages) == 1
      [message] = messages

      assert message.content == "Previous message"
      assert message.author.username == "TestUser"
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} = ListMessages.focus(%{
        channel_id: @channel_id
      }, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = ListMessages.view()
      assert lens.schema.required == ["channel_id"]
    end

    test "validates pagination parameters" do
      lens = ListMessages.view()

      # Verify limit parameter
      limit = lens.schema.properties.limit
      assert limit.type == :integer
      assert limit.minimum == 1
      assert limit.maximum == 100
      assert limit.default == 50

      # Verify before parameter
      before = lens.schema.properties.before
      assert before.type == :string
      assert before.pattern == "^[0-9]{17,20}$"

      # Verify after parameter
      after_param = lens.schema.properties.after
      assert after_param.type == :string
      assert after_param.pattern == "^[0-9]{17,20}$"

      # Verify around parameter
      around = lens.schema.properties.around
      assert around.type == :string
      assert around.pattern == "^[0-9]{17,20}$"
    end
  end
end
