defmodule Lux.Lenses.Telegram.Bot.GetWebhookInfoTest do
  @moduledoc """
  Test suite for the GetWebhookInfo lens.
  Verifies:
  - Active webhook info retrieval
  - Empty webhook (no webhook set) handling
  - Error states
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Bot.GetWebhookInfo

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "retrieves active webhook info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "getWebhookInfo"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "url" => "https://example.com/webhook",
            "has_custom_certificate" => false,
            "pending_update_count" => 5,
            "last_error_date" => nil,
            "last_error_message" => nil,
            "max_connections" => 40,
            "allowed_updates" => ["message", "callback_query"]
          }
        }))
      end)

      assert {:ok, result} = GetWebhookInfo.focus(%{}, %{})
      assert result.url == "https://example.com/webhook"
      assert result.has_custom_certificate == false
      assert result.pending_update_count == 5
      assert result.max_connections == 40
      assert result.allowed_updates == ["message", "callback_query"]
    end

    test "handles no webhook set" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "url" => "",
            "has_custom_certificate" => false,
            "pending_update_count" => 0
          }
        }))
      end)

      assert {:ok, result} = GetWebhookInfo.focus(%{}, %{})
      assert result.url == ""
      assert result.pending_update_count == 0
    end

    test "handles webhook with error info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "url" => "https://example.com/webhook",
            "has_custom_certificate" => false,
            "pending_update_count" => 100,
            "last_error_date" => 1_609_459_200,
            "last_error_message" => "Connection refused",
            "max_connections" => 40
          }
        }))
      end)

      assert {:ok, result} = GetWebhookInfo.focus(%{}, %{})
      assert result.last_error_date == 1_609_459_200
      assert result.last_error_message == "Connection refused"
    end

    test "handles API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Unauthorized"
        }))
      end)

      assert {:error, "Unauthorized"} = GetWebhookInfo.focus(%{}, %{})
    end
  end
end
