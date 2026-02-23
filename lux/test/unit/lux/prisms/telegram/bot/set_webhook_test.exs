defmodule Lux.Prisms.Telegram.Bot.SetWebhookTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Bot.SetWebhook

  @webhook_url "https://example.com/webhook"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets webhook with URL only" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

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

      assert {:ok, %{success: true, description: "Webhook was set"}} =
               SetWebhook.handler(
                 %{url: @webhook_url, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "successfully sets webhook with full options" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["url"] == @webhook_url
        assert decoded["max_connections"] == 50
        assert decoded["allowed_updates"] == ["message", "callback_query"]
        assert decoded["drop_pending_updates"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true,
          "description" => "Webhook was set"
        }))
      end)

      assert {:ok, %{success: true}} =
               SetWebhook.handler(
                 %{
                   url: @webhook_url,
                   max_connections: 50,
                   allowed_updates: ["message", "callback_query"],
                   drop_pending_updates: true,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "returns error when url is missing" do
      assert {:error, "url is required"} = SetWebhook.handler(%{}, @agent_ctx)
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

      assert {:error, "Failed to set webhook: " <> _} =
               SetWebhook.handler(
                 %{url: "http://insecure.com/webhook", plug: {Req.Test, __MODULE__}},
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
    end

    test "validates output schema" do
      prism = SetWebhook.view()
      assert "success" in prism.output_schema.required
      assert Map.has_key?(prism.output_schema.properties, :success)
      assert Map.has_key?(prism.output_schema.properties, :description)
    end
  end
end
