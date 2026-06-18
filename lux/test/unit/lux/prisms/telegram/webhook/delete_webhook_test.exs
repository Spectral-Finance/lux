defmodule Lux.Prisms.Telegram.Webhook.DeleteWebhookTest do
  use UnitAPICase, async: false

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
        assert conn.request_path == "/bottest_telegram_bot_token/deleteWebhook"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true}} =
               DeleteWebhook.handler(
                 %{},
                 @agent_ctx
               )
    end

    test "deletes webhook with drop_pending_updates" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

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
                 %{
                   drop_pending_updates: true
                 },
                 @agent_ctx
               )
    end

    test "handles error with map response from Telegram API" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "custom_error" => "unknown error occurred"
        }))
      end)

      assert {:error, "Failed to delete webhook: " <> _} =
               DeleteWebhook.handler(%{}, @agent_ctx)
    end

    test "handles error from Telegram API" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request"
        }))
      end)

      assert {:error, "Failed to delete webhook: Bad Request (HTTP 400)"} =
               DeleteWebhook.handler(%{}, @agent_ctx)
    end

    test "handles raw string error from Telegram API" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.send_resp(500, "Internal Server Error")
      end)

      assert {:error, "Failed to delete webhook: Internal Server Error (HTTP 500)"} =
               DeleteWebhook.handler(%{}, @agent_ctx)
    end

    test "handles transport error" do
      Application.put_env(:lux, Lux.Integrations.Telegram.Client, adapter: fn req -> {req, %Req.TransportError{reason: :timeout}} end)

      try do
        assert {:error, "Failed to delete webhook: %Req.TransportError{reason: :timeout}"} =
                 DeleteWebhook.handler(%{}, @agent_ctx)
      after
        Application.put_env(:lux, Lux.Integrations.Telegram.Client, [plug: {Req.Test, TelegramClientMock}, max_retries: 0])
      end
    end
  end
end
