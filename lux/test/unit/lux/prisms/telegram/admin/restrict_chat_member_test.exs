defmodule Lux.Prisms.Telegram.Admin.RestrictChatMemberTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Admin.RestrictChatMember

  @chat_id "123456789"
  @user_id 987654
  @agent_ctx %{name: "AdminAgent"}
  @permissions %{can_send_messages: false, can_send_photos: false}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully restricts a user with atom keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/restrictChatMember")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["user_id"] == @user_id
        assert decoded["permissions"]["can_send_messages"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = RestrictChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id,
        permissions: @permissions,
        until_date: 1_700_000_000
      }, @agent_ctx)

      assert response.success == true
    end

    test "successfully restricts a user with string keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["user_id"] == @user_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = RestrictChatMember.handler(%{
        "chat_id" => @chat_id,
        "user_id" => @user_id,
        "permissions" => @permissions
      }, %{})

      assert response.success == true
    end

    test "handles Telegram API error response" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Not enough rights to restrict member"
        }))
      end)

      assert {:error, message} = RestrictChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id,
        permissions: @permissions
      }, @agent_ctx)

      assert String.contains?(message, "Not enough rights")
    end

    test "returns error on missing required params" do
      assert {:error, "Missing or invalid chat_id"} = RestrictChatMember.handler(%{user_id: @user_id, permissions: @permissions}, @agent_ctx)
      assert {:error, "Missing or invalid user_id"} = RestrictChatMember.handler(%{chat_id: @chat_id, permissions: @permissions}, @agent_ctx)
      assert {:error, "Missing or invalid permissions"} = RestrictChatMember.handler(%{chat_id: @chat_id, user_id: @user_id}, @agent_ctx)
    end
  end
end
