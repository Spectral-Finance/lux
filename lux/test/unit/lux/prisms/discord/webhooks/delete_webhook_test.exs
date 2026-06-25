defmodule Lux.Prisms.Discord.Webhooks.DeleteWebhookTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Webhooks.DeleteWebhook

  @webhook_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "successfully deletes a webhook" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/api/v10/webhooks/#{@webhook_id}"

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{deleted: true, webhook_id: @webhook_id}} =
             DeleteWebhook.handler(%{webhook_id: @webhook_id}, %{})
  end
end
