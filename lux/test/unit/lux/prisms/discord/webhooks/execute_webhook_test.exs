defmodule Lux.Prisms.Discord.Webhooks.ExecuteWebhookTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Webhooks.ExecuteWebhook

  @webhook_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "successfully executes a webhook" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/v10/webhooks/#{@webhook_id}/token-123"
      assert conn.query_string == "wait=true"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"content" => "Build passed", "username" => "Lux"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "111111111111111111"}))
    end)

    assert {:ok, %{sent: true, message_id: "111111111111111111", webhook_id: @webhook_id}} =
             ExecuteWebhook.handler(
               %{
                 webhook_id: @webhook_id,
                 webhook_token: "token-123",
                 content: "Build passed",
                 username: "Lux"
               },
               %{}
             )
  end
end
