defmodule Lux.Prisms.Telegram.Admin.PromoteChatMemberTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Admin.PromoteChatMember

  @chat_id "123456789"
  @user_id 987654
  @agent_ctx %{name: "AdminAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully promotes a user with atom keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/promoteChatMember")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["user_id"] == @user_id
        assert decoded["can_delete_messages"] == true
        assert decoded["can_invite_users"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = PromoteChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id,
        can_delete_messages: true,
        can_invite_users: true
      }, @agent_ctx)

      assert response.success == true
    end

    test "successfully promotes a user with string keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["user_id"] == @user_id
        assert decoded["can_pin_messages"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = PromoteChatMember.handler(%{
        "chat_id" => @chat_id,
        "user_id" => @user_id,
        "can_pin_messages" => true
      }, %{})

      assert response.success == true
    end

    test "handles Telegram API error response" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Not enough rights to promote member"
        }))
      end)

      assert {:error, message} = PromoteChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id
      }, @agent_ctx)

      assert String.contains?(message, "Not enough rights")
    end

    test "returns error on missing required params" do
      assert {:error, "Missing or invalid chat_id"} = PromoteChatMember.handler(%{user_id: @user_id}, @agent_ctx)
      assert {:error, "Missing or invalid user_id"} = PromoteChatMember.handler(%{chat_id: @chat_id}, @agent_ctx)
    end
  end
end
