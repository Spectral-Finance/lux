defmodule Lux.Lenses.Telegram.Messages.DeleteMessageTest do
  @moduledoc """
  Unit tests for Lux.Lenses.Telegram.Messages.DeleteMessage.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Messages.DeleteMessage

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully deletes a message" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "/deleteMessage"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => true
          })
        )
      end)

      assert {:ok, %{deleted: true}} =
               DeleteMessage.focus(
                 %{
                   "chat_id" => "123456789",
                   "message_id" => 42
                 },
                 %{}
               )
    end

    test "handles message can't be deleted error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "/deleteMessage"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{
            "ok" => false,
            "error_code" => 400,
            "description" => "Bad Request: message can't be deleted"
          })
        )
      end)

      assert {:error, %{"description" => "Bad Request: message can't be deleted"}} =
               DeleteMessage.focus(
                 %{
                   "chat_id" => "123456789",
                   "message_id" => 42
                 },
                 %{}
               )
    end
  end

  describe "schema validation" do
    test "validates required parameters" do
      lens = DeleteMessage.view()
      assert lens.schema.required == ["chat_id", "message_id"]
      assert Map.has_key?(lens.schema.properties, :chat_id)
      assert Map.has_key?(lens.schema.properties, :message_id)
    end
  end
end
