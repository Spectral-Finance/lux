defmodule Lux.Prisms.Telegram.Bot.DeleteWebhookTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Bot.DeleteWebhook

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
          "result" => true,
          "description" => "Webhook was deleted"
        }))
      end)

      assert {:ok, %{success: true, description: "Webhook was deleted"}} =
               DeleteWebhook.handler(
                 %{plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "successfully deletes webhook with drop_pending_updates" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["drop_pending_updates"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true,
          "description" => "Webhook was deleted"
        }))
      end)

      assert {:ok, %{success: true}} =
               DeleteWebhook.handler(
                 %{drop_pending_updates: true, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "handles API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "ok" => false,
          "description" => "Unauthorized"
        }))
      end)

      assert {:error, "Failed to delete webhook: " <> _} =
               DeleteWebhook.handler(
                 %{plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates schema" do
      prism = DeleteWebhook.view()
      assert Map.has_key?(prism.input_schema.properties, :drop_pending_updates)
      assert "success" in prism.output_schema.required
    end
  end
end
