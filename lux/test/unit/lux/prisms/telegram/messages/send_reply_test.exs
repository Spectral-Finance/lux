defmodule Lux.Prisms.Telegram.Messages.SendReplyTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.SendReply

  @chat_id 123_456_789
  @message_id 42
  @reply_message_id 456
  @text "Great point! I agree."
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "sends a reply to a message" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendMessage")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["text"] == @text
        assert decoded["reply_to_message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{"message_id" => @reply_message_id}
        }))
      end)

      assert {:ok, %{sent: true, message_id: @reply_message_id, reply_to_message_id: @message_id}} =
               SendReply.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   text: @text,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "sends a forum thread reply with message_thread_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["message_thread_id"] == 10
        assert decoded["reply_to_message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{"message_id" => @reply_message_id}
        }))
      end)

      assert {:ok, %{sent: true}} =
               SendReply.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   message_thread_id: 10,
                   text: @text,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "sends a reply with parse_mode" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["parse_mode"] == "Markdown"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{"message_id" => @reply_message_id}
        }))
      end)

      assert {:ok, %{sent: true}} =
               SendReply.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   text: "*bold reply*",
                   parse_mode: "Markdown",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "handles API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: message to reply not found"
        }))
      end)

      assert {:error, "Bad Request: message to reply not found"} =
               SendReply.handler(
                 %{chat_id: @chat_id, message_id: 99999, text: @text, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end
  end
end
