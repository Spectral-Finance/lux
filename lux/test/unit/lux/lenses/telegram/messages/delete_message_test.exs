defmodule Lux.Lenses.Telegram.Messages.DeleteMessageTest do
  @moduledoc """
  Test suite for the DeleteMessage lens.
  These tests verify the lens's ability to:
  - Delete messages from Telegram chats
  - Handle Telegram API errors appropriately
  - Handle rate limiting (429 responses)
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Messages.DeleteMessage

  @chat_id 123_456_789
  @message_id 42

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully deletes a message" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/deleteMessage")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{deleted: true}} = DeleteMessage.focus(%{
        chat_id: @chat_id,
        message_id: @message_id
      }, %{})
    end

    test "handles Telegram API error - message not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 400,
          "description" => "Bad Request: message to delete not found"
        }))
      end)

      assert {:error, %{reason: :api_error, error_code: 400}} =
        DeleteMessage.focus(%{
          chat_id: @chat_id,
          message_id: @message_id
        }, %{})
    end

    test "handles rate limiting (429)" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests: retry after 10",
          "parameters" => %{"retry_after" => 10}
        }))
      end)

      assert {:error, %{reason: :rate_limited, retry_after: 10}} =
        DeleteMessage.focus(%{
          chat_id: @chat_id,
          message_id: @message_id
        }, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = DeleteMessage.view()
      assert lens.schema.required == ["chat_id", "message_id"]
    end

    test "validates schema properties" do
      lens = DeleteMessage.view()
      assert Map.has_key?(lens.schema.properties, :chat_id)
      assert Map.has_key?(lens.schema.properties, :message_id)
    end
  end
end
