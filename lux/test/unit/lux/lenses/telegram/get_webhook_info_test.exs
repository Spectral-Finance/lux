defmodule Lux.Lenses.Telegram.GetWebhookInfoTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Telegram.GetWebhookInfo

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully gets webhook info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/bottest_telegram_bot_token/getWebhookInfo"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "url" => "https://example.com/webhook",
            "has_custom_certificate" => false,
            "pending_update_count" => 0
          }
        }))
      end)

      assert {:ok, info} = GetWebhookInfo.focus()
      assert info["url"] == "https://example.com/webhook"
      assert info["has_custom_certificate"] == false
    end

    test "handles error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Internal Server Error"
        }))
      end)

      assert {:error, "Internal Server Error"} = GetWebhookInfo.focus()
    end

    test "handles unexpected response format" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "weird" => "format"
        }))
      end)

      assert {:error, "Unexpected response format: " <> _} = GetWebhookInfo.focus()
    end
  end
end
