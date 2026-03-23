defmodule Lux.Prisms.Telegram.Webhook.SetWebhookTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Webhook.SetWebhook

  @agent_ctx %{name: "TestAgent"}
  @webhook_url "https://example.com/webhook"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets webhook with required parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["url"] == @webhook_url

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true}} =
               SetWebhook.handler(
                 %{url: @webhook_url, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "successfully sets webhook with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["url"] == @webhook_url
        assert decoded_body["max_connections"] == 40
        assert decoded_body["allowed_updates"] == ["message", "callback_query"]
        assert decoded_body["drop_pending_updates"] == true
        assert decoded_body["secret_token"] == "my_secret"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true}} =
               SetWebhook.handler(
                 %{
                   url: @webhook_url,
                   max_connections: 40,
                   allowed_updates: ["message", "callback_query"],
                   drop_pending_updates: true,
                   secret_token: "my_secret",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates required url parameter" do
      result = SetWebhook.handler(%{}, @agent_ctx)
      assert result == {:error, "Missing or invalid url"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: bad webhook: HTTPS url must be provided for webhook"
        }))
      end)

      assert {:error, "Failed to set webhook: Bad Request: bad webhook: HTTPS url must be provided for webhook (HTTP 400)"} =
               SetWebhook.handler(
                 %{url: @webhook_url, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SetWebhook.view()
      assert prism.input_schema.required == ["url"]
      assert Map.has_key?(prism.input_schema.properties, :url)
      assert Map.has_key?(prism.input_schema.properties, :max_connections)
      assert Map.has_key?(prism.input_schema.properties, :allowed_updates)
      assert Map.has_key?(prism.input_schema.properties, :drop_pending_updates)
      assert Map.has_key?(prism.input_schema.properties, :secret_token)
    end

    test "validates output schema" do
      prism = SetWebhook.view()
      assert prism.output_schema.required == ["success"]
      assert Map.has_key?(prism.output_schema.properties, :success)
    end
  end
end
