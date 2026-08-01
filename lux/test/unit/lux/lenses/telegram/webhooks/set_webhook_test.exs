defmodule Lux.Lenses.Telegram.Webhooks.SetWebhookTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Webhooks.SetWebhook

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully sets a webhook" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/setWebhook")
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true,
          "description" => "Webhook was set"
        }))
      end)

      assert {:ok, result} = SetWebhook.focus(%{
        url: "https://example.com/webhook"
      }, %{})

      assert result[:result] == true
      assert result[:description] == "Webhook was set"
    end
  end
end
