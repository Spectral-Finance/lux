defmodule Lux.Lenses.Telegram.Webhooks.WebhookTest do
  @moduledoc """
  Unit tests for Lux.Lenses.Telegram.Webhooks (SetWebhook & GetWebhookInfo).
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Webhooks.SetWebhook
  alias Lux.Lenses.Telegram.Webhooks.GetWebhookInfo

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "SetWebhook" do
    test "successfully sets a webhook URL" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "/setWebhook"

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

      assert {:ok, %{success: true, description: "Webhook was set"}} =
               SetWebhook.focus(
                 %{
                   "url" => "https://agent.lux.network/webhook",
                   "secret_token" => "secret_123"
                 },
                 %{}
               )
    end
  end

  describe "GetWebhookInfo" do
    test "fetches current webhook status" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "/getWebhookInfo"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "url" => "https://agent.lux.network/webhook",
              "has_custom_certificate" => false,
              "pending_update_count" => 0,
              "max_connections" => 40
            }
          })
        )
      end)

      assert {:ok,
              %{
                url: "https://agent.lux.network/webhook",
                has_custom_certificate: false,
                pending_update_count: 0,
                max_connections: 40
              }} = GetWebhookInfo.focus(%{}, %{})
    end
  end
end
