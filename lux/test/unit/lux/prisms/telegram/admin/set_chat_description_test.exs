defmodule Lux.Prisms.Telegram.Admin.SetChatDescriptionTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Admin.SetChatDescription

  @chat_id "123456789"
  @description "Official community group for Lux Autonomous Agents"
  @agent_ctx %{name: "AdminAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets chat description with atom keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/setChatDescription")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["description"] == @description

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = SetChatDescription.handler(%{
        chat_id: @chat_id,
        description: @description
      }, @agent_ctx)

      assert response.success == true
    end

    test "successfully sets chat description with string keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = SetChatDescription.handler(%{
        "chat_id" => @chat_id
      }, %{})

      assert response.success == true
    end

    test "handles Telegram API error response" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Chat description is too long"
        }))
      end)

      assert {:error, message} = SetChatDescription.handler(%{
        chat_id: @chat_id,
        description: @description
      }, @agent_ctx)

      assert String.contains?(message, "too long")
    end

    test "returns error on missing required params" do
      assert {:error, "Missing or invalid chat_id"} = SetChatDescription.handler(%{}, @agent_ctx)
    end
  end
end
