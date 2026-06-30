defmodule Lux.Lenses.Discord.Messages.ReadMessageTest do
  @moduledoc """
  Test suite for the ReadMessage module.
  These tests verify the lens's ability to:
  - Read messages from Discord channels
  - Handle Discord API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Messages.ReadMessage

  @channel_id "123456789012345678"
  @message_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully reads a message" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages/:message_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @message_id,
          "channel_id" => @channel_id,
          "content" => "Test message",
          "author" => %{
            "id" => "111222333444555666",
            "username" => "TestBot"
          }
        }))
      end)

      assert {:ok, %{
        content: "Test message",
        author: %{
          id: "111222333444555666",
          username: "TestBot"
        }
      }} = ReadMessage.focus(%{
        "channel_id" => @channel_id,
        "message_id" => @message_id
      }, %{})
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages/:message_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} = ReadMessage.focus(%{
        "channel_id" => @channel_id,
        "message_id" => @message_id
      }, %{})
    end

    test "crashes on unexpected response format" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages/:message_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert_raise FunctionClauseError, fn ->
        ReadMessage.focus(%{
          "channel_id" => @channel_id,
          "message_id" => @message_id
        }, %{})
      end
    end
  end

  describe "schema validation" do
    test "validates schema" do
      lens = ReadMessage.view()
      assert lens.schema.required == ["channel_id", "message_id"]
      assert Map.has_key?(lens.schema.properties, :channel_id)
      assert Map.has_key?(lens.schema.properties, :message_id)
    end
  end
end
