defmodule Lux.Lenses.Telegram.Webhooks.SetWebhookTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Telegram.Webhooks.SetWebhook

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "sets webhook via lens" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/setWebhook")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["url"] == "https://agent.example.com/webhook"
        assert decoded["secret_token"] == "secret123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => true,
            "description" => "Webhook was set"
          })
        )
      end)

      assert {:ok, result} =
               SetWebhook.focus(
                 %{
                   "url" => "https://agent.example.com/webhook",
                   "secret_token" => "secret123"
                 },
                 %{}
               )

      assert result.status == :ok
      assert result.description == "Webhook was set"
    end
  end
end
