defmodule Lux.Lenses.Telegram.Bot.SetWebhookTest do
  @moduledoc """
  Test suite for the SetWebhook lens.
  These tests verify the lens's ability to:
  - Set webhook URLs for Telegram bot updates
  - Handle optional parameters (max_connections, allowed_updates, etc.)
  - Handle Telegram API errors appropriately
  - Handle rate limiting (429 responses)
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Bot.SetWebhook

  @webhook_url "https://example.com/webhook/telegram"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully sets a webhook" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/setWebhook")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["url"] == @webhook_url

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true,
          "description" => "Webhook was set"
        }))
      end)

      assert {:ok, %{set: true, description: "Webhook was set"}} =
        SetWebhook.focus(%{url: @webhook_url}, %{})
    end

    test "successfully sets a webhook with optional parameters" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["url"] == @webhook_url
        assert decoded["max_connections"] == 40
        assert decoded["allowed_updates"] == ["message", "callback_query"]
        assert decoded["secret_token"] == "my-secret"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true,
          "description" => "Webhook was set"
        }))
      end)

      assert {:ok, %{set: true}} = SetWebhook.focus(%{
        url: @webhook_url,
        max_connections: 40,
        allowed_updates: ["message", "callback_query"],
        secret_token: "my-secret"
      }, %{})
    end

    test "handles Telegram API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 400,
          "description" => "Bad Request: bad webhook: HTTPS url must be provided for webhook"
        }))
      end)

      assert {:error, %{reason: :api_error, error_code: 400}} =
        SetWebhook.focus(%{url: "http://example.com/webhook"}, %{})
    end

    test "handles rate limiting (429)" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests: retry after 20",
          "parameters" => %{"retry_after" => 20}
        }))
      end)

      assert {:error, %{reason: :rate_limited, retry_after: 20}} =
        SetWebhook.focus(%{url: @webhook_url}, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = SetWebhook.view()
      assert lens.schema.required == ["url"]
    end

    test "validates schema properties" do
      lens = SetWebhook.view()
      assert Map.has_key?(lens.schema.properties, :url)
      assert Map.has_key?(lens.schema.properties, :max_connections)
      assert Map.has_key?(lens.schema.properties, :allowed_updates)
      assert Map.has_key?(lens.schema.properties, :secret_token)
      assert Map.has_key?(lens.schema.properties, :drop_pending_updates)
    end

    test "validates max_connections constraints" do
      lens = SetWebhook.view()
      mc = lens.schema.properties.max_connections
      assert mc.minimum == 1
      assert mc.maximum == 100
      assert mc.default == 40
    end
  end
end
