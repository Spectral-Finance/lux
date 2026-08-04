defmodule Lux.Integrations.Telegram.WebhookTest do
  use UnitAPICase, async: true
  use Plug.Test

  alias Lux.Integrations.Telegram.Webhook

  defmodule DummyHandler do
    def handle_update(%{"update_id" => 123}), do: :ok
    def handle_update(_), do: :error
  end

  setup do
    opts = Webhook.init(secret_token: "secret_123", handler: DummyHandler)
    %{opts: opts}
  end

  test "returns 401 when secret token is missing", %{opts: opts} do
    conn = 
      conn(:post, "/webhook", %{"update_id" => 123})
      |> Webhook.call(opts)

    assert conn.status == 401
    assert conn.resp_body == "Unauthorized"
  end

  test "returns 401 when secret token is invalid", %{opts: opts} do
    conn = 
      conn(:post, "/webhook", %{"update_id" => 123})
      |> put_req_header("x-telegram-bot-api-secret-token", "wrong_secret")
      |> Webhook.call(opts)

    assert conn.status == 401
    assert conn.resp_body == "Unauthorized"
  end

  test "returns 200 and processes update when secret token is valid", %{opts: opts} do
    conn = 
      conn(:post, "/webhook", %{"update_id" => 123})
      |> put_req_header("x-telegram-bot-api-secret-token", "secret_123")
      |> Webhook.call(opts)

    assert conn.status == 200
    assert conn.resp_body == "OK"
  end
end
