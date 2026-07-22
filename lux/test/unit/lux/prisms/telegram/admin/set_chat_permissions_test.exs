defmodule Lux.Prisms.Telegram.Admin.SetChatPermissionsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Admin.SetChatPermissions

  @chat_id "123456789"
  @agent_ctx %{name: "AdminAgent"}
  @permissions %{can_send_messages: true, can_send_photos: false}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets chat permissions with atom keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/setChatPermissions")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["permissions"]["can_send_messages"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = SetChatPermissions.handler(%{
        chat_id: @chat_id,
        permissions: @permissions
      }, @agent_ctx)

      assert response.success == true
    end

    test "successfully sets chat permissions with string keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = SetChatPermissions.handler(%{
        "chat_id" => @chat_id,
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
          "description" => "Chat not found"
        }))
      end)

      assert {:error, message} = SetChatPermissions.handler(%{
        chat_id: @chat_id,
        permissions: @permissions
      }, @agent_ctx)

      assert String.contains?(message, "Chat not found")
    end

    test "returns error on missing required params" do
      assert {:error, "Missing or invalid chat_id"} = SetChatPermissions.handler(%{permissions: @permissions}, @agent_ctx)
      assert {:error, "Missing or invalid permissions"} = SetChatPermissions.handler(%{chat_id: @chat_id}, @agent_ctx)
    end
  end
end
