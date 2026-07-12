defmodule Lux.Prisms.Telegram.GroupManagement.RestrictChatMemberTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.GroupManagement.RestrictChatMember

  @chat_id 123_456_789
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully executes restrict member" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["user_id"] == 987_654
        assert decoded_body["permissions"]["can_send_messages"] == true


        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true, chat_id: @chat_id}} =
               RestrictChatMember.handler(
                 %{
                   chat_id: @chat_id,
                   user_id: 987_654,
                   permissions: %{can_send_messages: true},
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates required parameters" do
      result = RestrictChatMember.handler(%{}, @agent_ctx)
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

      assert {:error, "Failed to restrict member: Bad Request: error description (HTTP 400)"} =
               RestrictChatMember.handler(
                 %{
                   chat_id: @chat_id,
                   user_id: 987_654,
                   permissions: %{can_send_messages: true},
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = RestrictChatMember.view()
      assert Enum.sort(prism.input_schema.required) == Enum.sort(["chat_id", "user_id", "permissions"])
    end

    test "validates output schema" do
      prism = RestrictChatMember.view()
      assert Enum.sort(prism.output_schema.required) == ["chat_id", "success"]
    end
  end
end
