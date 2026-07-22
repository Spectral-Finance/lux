defmodule Lux.Prisms.Telegram.Settings.SetChatTitleTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Settings.SetChatTitle

  @chat_id "123456789"
  @agent_ctx %{name: "Agent"}
  @title "New Group Title"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets chat title" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/setChatTitle")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["title"] == @title

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, response} = SetChatTitle.handler(%{
        chat_id: @chat_id,
        title: @title,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.success == true
    end
  end
end
