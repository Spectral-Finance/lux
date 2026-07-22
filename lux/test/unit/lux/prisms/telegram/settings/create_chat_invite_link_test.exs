defmodule Lux.Prisms.Telegram.Settings.CreateChatInviteLinkTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Settings.CreateChatInviteLink

  @chat_id "123456789"
  @agent_ctx %{name: "Agent"}
  @invite_link "https://t.me/+AbCdEfGhIjKlMnOp"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates invite link" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/createChatInviteLink")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["name"] == "Promo Link"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "invite_link" => @invite_link,
            "name" => "Promo Link",
            "creator" => %{"id" => 12345, "first_name" => "Bot", "is_bot" => true}
          }
        }))
      end)

      assert {:ok, response} = CreateChatInviteLink.handler(%{
        chat_id: @chat_id,
        name: "Promo Link",
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.invite_link == @invite_link
      assert response.name == "Promo Link"
    end

    test "explicitly passes false values for creates_join_request" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["creates_join_request"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "invite_link" => @invite_link
          }
        }))
      end)

      assert {:ok, response} = CreateChatInviteLink.handler(%{
        chat_id: @chat_id,
        creates_join_request: false,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.invite_link == @invite_link
    end
  end
end
