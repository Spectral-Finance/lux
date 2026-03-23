defmodule Lux.Prisms.Telegram.Webhook.DeleteWebhookTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Webhook.DeleteWebhook

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully deletes webhook" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true}} =
               DeleteWebhook.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end

    test "successfully deletes webhook with drop_pending_updates" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["drop_pending_updates"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true}} =
               DeleteWebhook.handler(
                 %{drop_pending_updates: true, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
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

      assert {:error, "Failed to delete webhook: :invalid_token"} =
               DeleteWebhook.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = DeleteWebhook.view()
      assert prism.input_schema.required == []
      assert Map.has_key?(prism.input_schema.properties, :drop_pending_updates)
    end

    test "validates output schema" do
      prism = DeleteWebhook.view()
      assert prism.output_schema.required == ["success"]
      assert Map.has_key?(prism.output_schema.properties, :success)
    end
  end
end
