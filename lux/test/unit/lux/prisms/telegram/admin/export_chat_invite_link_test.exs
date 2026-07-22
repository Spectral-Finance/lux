defmodule Lux.Prisms.Telegram.Admin.ExportChatInviteLinkTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Admin.ExportChatInviteLink

  @chat_id "123456789"
  @invite_link "https://t.me/+AbCdEfGhIjKlMnOp"
  @agent_ctx %{name: "AdminAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully exports chat invite link with atom keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/exportChatInviteLink")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => @invite_link}))
      end)

      assert {:ok, response} = ExportChatInviteLink.handler(%{
        chat_id: @chat_id
      }, @agent_ctx)

      assert response.invite_link == @invite_link
    end

    test "successfully exports chat invite link with string keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => @invite_link}))
      end)

      assert {:ok, response} = ExportChatInviteLink.handler(%{
        "chat_id" => @chat_id
      }, %{})

      assert response.invite_link == @invite_link
    end

    test "handles Telegram API error response" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Not enough rights to export invite link"
        }))
      end)

      assert {:error, message} = ExportChatInviteLink.handler(%{
        chat_id: @chat_id
      }, @agent_ctx)

      assert String.contains?(message, "Not enough rights")
    end

    test "returns error on missing required params" do
      assert {:error, "Missing or invalid chat_id"} = ExportChatInviteLink.handler(%{}, @agent_ctx)
    end
  end
end
