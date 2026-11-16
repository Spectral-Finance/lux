defmodule Lux.Lenses.Telegram.Messages.EditMessageTest do
  @moduledoc """
  Unit tests for Lux.Lenses.Telegram.Messages.EditMessage.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Messages.EditMessage

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully edits a message" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "/editMessageText"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "message_id" => 42,
              "edit_date" => 1_700_000_050,
              "chat" => %{"id" => 123_456_789},
              "text" => "Updated content"
            }
          })
        )
      end)

      assert {:ok,
              %{
                message_id: 42,
                chat_id: 123_456_789,
                text: "Updated content",
                edit_date: 1_700_000_050
              }} =
               EditMessage.focus(
                 %{
                   "chat_id" => "123456789",
                   "message_id" => 42,
                   "text" => "Updated content"
                 },
                 %{}
               )
    end

    test "handles message not modified or not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "/editMessageText"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{
            "ok" => false,
            "error_code" => 400,
            "description" => "Bad Request: message is not modified"
          })
        )
      end)

      assert {:error, %{"description" => "Bad Request: message is not modified"}} =
               EditMessage.focus(
                 %{
                   "chat_id" => "123456789",
                   "message_id" => 42,
                   "text" => "Same content"
                 },
                 %{}
               )
    end
  end

  describe "schema validation" do
    test "validates required parameters" do
      lens = EditMessage.view()
      assert lens.schema.required == ["text"]
      assert Map.has_key?(lens.schema.properties, :text)
      assert Map.has_key?(lens.schema.properties, :message_id)
      assert Map.has_key?(lens.schema.properties, :chat_id)
    end
  end
end
