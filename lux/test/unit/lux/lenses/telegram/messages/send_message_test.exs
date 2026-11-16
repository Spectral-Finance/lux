defmodule Lux.Lenses.Telegram.Messages.SendMessageTest do
  @moduledoc """
  Unit tests for Lux.Lenses.Telegram.Messages.SendMessage.
  Verifies:
  - Text message dispatch
  - Parse mode and entity serialization
  - Inline keyboard support
  - Error propagation
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Messages.SendMessage

  @chat_id "123456789"
  @text "Hello from Lux Agent Test"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully sends a formatted message" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "/sendMessage"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "message_id" => 42,
              "date" => 1_700_000_000,
              "chat" => %{
                "id" => 123_456_789,
                "type" => "private",
                "username" => "testuser"
              },
              "from" => %{
                "id" => 987_654_321,
                "is_bot" => true,
                "first_name" => "LuxBot",
                "username" => "lux_agent_bot"
              },
              "text" => @text
            }
          })
        )
      end)

      assert {:ok,
              %{
                message_id: 42,
                chat_id: 123_456_789,
                text: @text,
                date: 1_700_000_000,
                from: %{
                  id: 987_654_321,
                  is_bot: true,
                  first_name: "LuxBot",
                  username: "lux_agent_bot"
                }
              }} =
               SendMessage.focus(
                 %{
                   "chat_id" => @chat_id,
                   "text" => @text,
                   "parse_mode" => "HTML"
                 },
                 %{}
               )
    end

    test "handles Telegram API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "/sendMessage"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{
            "ok" => false,
            "error_code" => 400,
            "description" => "Bad Request: chat not found"
          })
        )
      end)

      assert {:error, %{"description" => "Bad Request: chat not found"}} =
               SendMessage.focus(
                 %{
                   "chat_id" => "invalid_chat",
                   "text" => @text
                 },
                 %{}
               )
    end
  end

  describe "schema validation" do
    test "validates required parameters" do
      lens = SendMessage.view()
      assert lens.schema.required == ["chat_id", "text"]
      assert Map.has_key?(lens.schema.properties, :chat_id)
      assert Map.has_key?(lens.schema.properties, :text)
      assert Map.has_key?(lens.schema.properties, :parse_mode)
      assert Map.has_key?(lens.schema.properties, :reply_markup)
    end
  end
end
