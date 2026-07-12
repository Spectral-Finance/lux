defmodule Lux.Prisms.Telegram.GroupManagement.DeleteMessageTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.GroupManagement.DeleteMessage

  @chat_id 123_456_789
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully executes delete message" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["message_id"] == 101

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true, chat_id: @chat_id}} =
               DeleteMessage.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: 101,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates required parameters" do
      result = DeleteMessage.handler(%{}, @agent_ctx)
      assert result == {:error, "Missing or invalid chat_id"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: error description"
        }))
      end)

      assert {:error, "Failed to delete message: Bad Request: error description (HTTP 400)"} =
               DeleteMessage.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: 101,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = DeleteMessage.view()
      assert Enum.sort(prism.input_schema.required) == Enum.sort(["chat_id", "message_id"])
    end

    test "validates output schema" do
      prism = DeleteMessage.view()
      assert Enum.sort(prism.output_schema.required) == ["chat_id", "success"]
    end
  end
end
