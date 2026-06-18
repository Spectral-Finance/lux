defmodule Lux.Prisms.Telegram.Webhook.SetWebhookTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.Telegram.Webhook.SetWebhook

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets webhook with URL" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bottest_telegram_bot_token/setWebhook"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["url"] == "https://example.com/webhook"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true,
          "description" => "Webhook was set"
        }))
      end)

      assert {:ok, %{success: true, url: "https://example.com/webhook"}} =
               SetWebhook.handler(
                 %{
                   url: "https://example.com/webhook"
                 },
                 @agent_ctx
               )
    end

    test "successfully sets webhook with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["url"] == "https://example.com/webhook"
        assert decoded_body["secret_token"] == "my-secret-token"
        assert decoded_body["max_connections"] == 50
        assert decoded_body["drop_pending_updates"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true, url: "https://example.com/webhook"}} =
               SetWebhook.handler(
                 %{
                   url: "https://example.com/webhook",
                   secret_token: "my-secret-token",
                   max_connections: 50,
                   drop_pending_updates: true
                 },
                 @agent_ctx
               )
    end

    test "successfully sets webhook with certificate file" do
      tmp_path = Path.join(System.tmp_dir!(), "cert_#{:erlang.unique_integer([:positive])}.pem")
      File.write!(tmp_path, "fake cert content")

      try do
        Req.Test.expect(TelegramClientMock, fn conn ->
          assert conn.method == "POST"
          assert conn.request_path == "/bottest_telegram_bot_token/setWebhook"
          [content_type] = Plug.Conn.get_req_header(conn, "content-type")
          assert String.starts_with?(content_type, "multipart/form-data")

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{
            "ok" => true,
            "result" => true
          }))
        end)

        assert {:ok, %{success: true, url: "https://example.com/webhook"}} =
                 SetWebhook.handler(
                   %{
                     url: "https://example.com/webhook",
                     certificate: tmp_path
                   },
                   @agent_ctx
                 )
      after
        File.rm(tmp_path)
      end
    end

    test "handles error with map response from Telegram API" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "error_code" => 400,
          "custom_error_field" => "something went wrong"
        }))
      end)

      assert {:error, "Failed to set webhook: " <> _} =
               SetWebhook.handler(
                 %{
                   url: "https://example.com/webhook"
                 },
                 @agent_ctx
               )
    end

    test "handles error from Telegram API" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: invalid URL"
        }))
      end)

      assert {:error, "Failed to set webhook: Bad Request: invalid URL (HTTP 400)"} =
               SetWebhook.handler(
                 %{
                   url: "invalid_url"
                 },
                 @agent_ctx
               )
    end

    test "handles raw string error from Telegram API" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.send_resp(500, "Internal Server Error")
      end)

      assert {:error, "Failed to set webhook: Internal Server Error (HTTP 500)"} =
               SetWebhook.handler(
                 %{
                   url: "https://example.com/webhook"
                 },
                 @agent_ctx
               )
    end

    test "handles transport error" do
      Application.put_env(:lux, Lux.Integrations.Telegram.Client, adapter: fn req -> {req, %Req.TransportError{reason: :timeout}} end)

      try do
        assert {:error, "Failed to set webhook: %Req.TransportError{reason: :timeout}"} =
                 SetWebhook.handler(
                   %{
                     url: "https://example.com/webhook"
                   },
                   @agent_ctx
                 )
      after
        Application.put_env(:lux, Lux.Integrations.Telegram.Client, [plug: {Req.Test, TelegramClientMock}, max_retries: 0])
      end
    end

    test "validates required parameters" do
      assert {:error, "Missing or invalid url"} = SetWebhook.handler(%{}, @agent_ctx)
      assert {:error, "Missing or invalid url"} = SetWebhook.handler(%{url: nil}, @agent_ctx)
    end
  end
end
