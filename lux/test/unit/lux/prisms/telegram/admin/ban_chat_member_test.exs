defmodule Lux.Prisms.Telegram.Admin.BanChatMemberTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Admin.BanChatMember

  @chat_id "123456789"
  @user_id 987654
  @agent_ctx %{name: "AdminAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully bans a user with atom keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/banChatMember")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["user_id"] == @user_id
        assert decoded["revoke_messages"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = BanChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id,
        revoke_messages: true
      }, @agent_ctx)

      assert response.success == true
    end

    test "successfully bans a user with string keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["user_id"] == @user_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = BanChatMember.handler(%{
        "chat_id" => @chat_id,
        "user_id" => @user_id
      }, %{})

      assert response.success == true
    end

    test "handles Telegram API error response" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "User not found"
        }))
      end)

      assert {:error, message} = BanChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id
      }, @agent_ctx)

      assert String.contains?(message, "User not found")
    end

    test "returns error on missing required params" do
      assert {:error, "Missing or invalid chat_id"} = BanChatMember.handler(%{user_id: @user_id}, @agent_ctx)
      assert {:error, "Missing or invalid user_id"} = BanChatMember.handler(%{chat_id: @chat_id}, @agent_ctx)
    end
  end
end
