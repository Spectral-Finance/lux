defmodule Lux.Prisms.Telegram.Settings.RevokeChatInviteLinkTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Settings.RevokeChatInviteLink

  @chat_id "123456789"
  @agent_ctx %{name: "Agent"}
  @invite_link "https://t.me/+AbCdEfGhIjKlMnOp"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully revokes invite link" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/revokeChatInviteLink")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["invite_link"] == @invite_link

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "invite_link" => @invite_link,
            "is_revoked" => true
          }
        }))
      end)

      assert {:ok, response} = RevokeChatInviteLink.handler(%{
        chat_id: @chat_id,
        invite_link: @invite_link,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.success == true
      assert response.revoked_link["is_revoked"] == true
    end
  end
end
