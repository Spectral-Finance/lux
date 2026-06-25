defmodule Lux.Prisms.Discord.Webhooks.UpdateWebhookTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Webhooks.UpdateWebhook

  @webhook_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "successfully updates a webhook" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/api/v10/webhooks/#{@webhook_id}"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"name" => "alerts"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @webhook_id, "name" => "alerts"}))
    end)

    assert {:ok, %{updated: true, webhook_id: @webhook_id, name: "alerts"}} =
             UpdateWebhook.handler(%{webhook_id: @webhook_id, name: "alerts"}, %{})
  end

  test "requires at least one field to update" do
    assert {:error, "At least one webhook field is required"} =
             UpdateWebhook.handler(%{webhook_id: @webhook_id}, %{})
  end
end
