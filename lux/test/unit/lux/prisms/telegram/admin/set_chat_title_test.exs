defmodule Lux.Prisms.Telegram.Admin.SetChatTitleTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Admin.SetChatTitle

  @chat_id "123456789"
  @title "New Super Group Title"
  @agent_ctx %{name: "AdminAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets chat title with atom keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/setChatTitle")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["title"] == @title

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = SetChatTitle.handler(%{
        chat_id: @chat_id,
        title: @title
      }, @agent_ctx)

      assert response.success == true
    end

    test "successfully sets chat title with string keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["title"] == @title

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = SetChatTitle.handler(%{
        "chat_id" => @chat_id,
        "title" => @title
      }, %{})

      assert response.success == true
    end

    test "handles Telegram API error response" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Not enough rights to change chat title"
        }))
      end)

      assert {:error, message} = SetChatTitle.handler(%{
        chat_id: @chat_id,
        title: @title
      }, @agent_ctx)

      assert String.contains?(message, "Not enough rights")
    end

    test "returns error on missing required params" do
      assert {:error, "Missing or invalid chat_id"} = SetChatTitle.handler(%{title: @title}, @agent_ctx)
      assert {:error, "Missing or invalid title"} = SetChatTitle.handler(%{chat_id: @chat_id}, @agent_ctx)
    end
  end
end
