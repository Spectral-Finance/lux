defmodule Lux.Prisms.Telegram.Webhook.GetWebhookInfoTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Webhook.GetWebhookInfo

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully retrieves webhook info" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "url" => "https://example.com/webhook",
            "has_custom_certificate" => false,
            "pending_update_count" => 0,
            "max_connections" => 40,
            "allowed_updates" => ["message", "callback_query"]
          }
        }))
      end)

      assert {:ok, %{
        url: "https://example.com/webhook",
        has_custom_certificate: false,
        pending_update_count: 0,
        max_connections: 40,
        allowed_updates: ["message", "callback_query"]
      }} = GetWebhookInfo.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end

    test "retrieves webhook info with error details" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "url" => "https://example.com/webhook",
            "has_custom_certificate" => false,
            "pending_update_count" => 5,
            "last_error_date" => 1_234_567_890,
            "last_error_message" => "Connection timed out"
          }
        }))
      end)

      assert {:ok, %{
        url: "https://example.com/webhook",
        pending_update_count: 5,
        last_error_date: 1_234_567_890,
        last_error_message: "Connection timed out"
      }} = GetWebhookInfo.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "ok" => false,
          "description" => "Unauthorized"
        }))
      end)

      assert {:error, "Failed to get webhook info: :invalid_token"} =
               GetWebhookInfo.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = GetWebhookInfo.view()
      assert prism.input_schema.required == []
    end

    test "validates output schema" do
      prism = GetWebhookInfo.view()
      assert prism.output_schema.required == ["url", "has_custom_certificate", "pending_update_count"]
      assert Map.has_key?(prism.output_schema.properties, :url)
      assert Map.has_key?(prism.output_schema.properties, :has_custom_certificate)
      assert Map.has_key?(prism.output_schema.properties, :pending_update_count)
    end
  end
end
