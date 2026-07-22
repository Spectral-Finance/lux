defmodule Lux.Prisms.Telegram.Moderation.UnbanChatMemberTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Moderation.UnbanChatMember

  @chat_id "123456789"
  @user_id 987654
  @agent_ctx %{name: "Agent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully unbans a user" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/unbanChatMember")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["user_id"] == @user_id
        assert decoded["only_if_banned"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, response} = UnbanChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id,
        only_if_banned: true,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.success == true
    end

    test "handles error response" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Chat not found"
        }))
      end)

      assert {:error, message} = UnbanChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert String.contains?(message, "Chat not found")
    end
  end
end
