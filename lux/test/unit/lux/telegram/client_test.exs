defmodule Lux.Telegram.ClientTest do
  use UnitAPICase, async: false

  alias Lux.Telegram.Client
  alias Lux.Telegram.Types.{User, WebhookInfo}


  @bot_token "test_client_token_12345"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "new/1,2 struct initialization" do
    test "creates client with explicit token" do
      client = Client.new(@bot_token)
      assert client.token == @bot_token
      assert client.base_url == "https://api.telegram.org/bot"
      assert client.req_options == []
    end

    test "creates client with options keyword / map" do
      client = Client.new(token: @bot_token, base_url: "https://custom.tg.api/bot", req_options: [timeout: 5000])
      assert client.token == @bot_token
      assert client.base_url == "https://custom.tg.api/bot"
      assert client.req_options == [timeout: 5000]

      client_map = Client.new(%{token: @bot_token, base_url: "https://custom.tg.api/bot"})
      assert client_map.token == @bot_token
      assert client_map.base_url == "https://custom.tg.api/bot"
    end

    test "creates default client when nil passed" do
      client = Client.new()
      assert %Client{} = client
      assert client.base_url == "https://api.telegram.org/bot"
    end
  end

  describe "build_url/3" do
    test "interpolates token and endpoint correctly" do
      assert Client.build_url("https://api.telegram.org/bot", "123", "getMe") ==
               "https://api.telegram.org/bot123/getMe"

      assert Client.build_url("https://api.telegram.org/bot", "123", "/getMe") ==
               "https://api.telegram.org/bot123/getMe"

      assert Client.build_url("https://api.telegram.org/bot{token}", "123", "/sendMessage") ==
               "https://api.telegram.org/bot123/sendMessage"

      assert Client.build_url("https://custom-proxy.com", "123", "/getMe") ==
               "https://custom-proxy.com/bot123/getMe"
    end
  end

  describe "request/2,3,4 HTTP dispatching" do
    test "dispatches GET request with client struct" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/bot#{@bot_token}/getMe"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{"id" => 123, "username" => "test_bot"}
        }))
      end)

      assert {:ok, resp} = Client.request(client, :get, "/getMe", [])
      assert resp["ok"] == true
      assert resp["result"]["username"] == "test_bot"
    end

    test "dispatches POST request with JSON payload" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bot#{@bot_token}/sendMessage"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)
        assert json["chat_id"] == 123
        assert json["text"] == "test message"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{"message_id" => 100}
        }))
      end)

      assert {:ok, resp} = Client.request(client, :post, "/sendMessage", json: %{chat_id: 123, text: "test message"})
      assert resp["ok"] == true
      assert resp["result"]["message_id"] == 100
    end

    test "handles 401 invalid token response" do
      client = Client.new("invalid_tok")

      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "ok" => false,
          "error_code" => 401,
          "description" => "Unauthorized"
        }))
      end)

      assert {:error, :invalid_token} = Client.request(client, :get, "/getMe")
    end

    test "handles 400 error description response" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "error_code" => 400,
          "description" => "Bad Request: chat not found"
        }))
      end)

      assert {:error, {400, "Bad Request: chat not found"}} = Client.request(client, :post, "/sendMessage", json: %{chat_id: 0})
    end

    test "handles 429 rate limit response" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests: retry after 2",
          "parameters" => %{"retry_after" => 2}
        }))
      end)

      assert {:error, {429, body}} = Client.request(client, :get, "/getMe", max_rate_limit_retries: 0)
      assert body["parameters"]["retry_after"] == 2
    end
  end

  describe "bot management helpers" do
    test "get_me/1 returns Types.User struct on success" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "id" => 12345,
            "is_bot" => true,
            "first_name" => "Botty",
            "username" => "botty_bot"
          }
        }))
      end)

      assert {:ok, %User{} = user} = Client.get_me(client)
      assert user.id == 12345
      assert user.first_name == "Botty"
      assert user.username == "botty_bot"
    end

    test "get_webhook_info/1 returns Types.WebhookInfo struct on success" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "url" => "https://example.com/tg/webhook",
            "has_custom_certificate" => false,
            "pending_update_count" => 0
          }
        }))
      end)

      assert {:ok, %WebhookInfo{} = info} = Client.get_webhook_info(client)
      assert info.url == "https://example.com/tg/webhook"
      assert info.pending_update_count == 0
    end
  end

  describe "media delegations and client-first helpers" do
    test "get_file/1,2 and get_file(client, file_id, opts)" do
      client = Client.new(@bot_token)

      # 1. Client-first call
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bot#{@bot_token}/getFile"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{"file_id" => "fid_1", "file_path" => "photos/f1.jpg"}
        }))
      end)

      assert {:ok, resp1} = Client.get_file(client, "fid_1")
      assert resp1["result"]["file_path"] == "photos/f1.jpg"

      # 2. Direct delegation call with opts
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bot#{@bot_token}/getFile"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{"file_id" => "fid_2", "file_path" => "photos/f2.jpg"}
        }))
      end)

      assert {:ok, resp2} = Client.get_file("fid_2", token: @bot_token)
      assert resp2["result"]["file_path"] == "photos/f2.jpg"
    end

    test "download_file/1,2 and download_file(client, path_or_id, opts)" do
      client = Client.new(@bot_token)

      # Client-first download by direct file_path
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/file/bot#{@bot_token}/documents/report.pdf"

        conn
        |> Plug.Conn.put_resp_content_type("application/pdf")
        |> Plug.Conn.send_resp(200, "BINARY_PDF_DATA")
      end)

      assert {:ok, "BINARY_PDF_DATA"} = Client.download_file(client, "documents/report.pdf")

      # Direct delegation download by file_id (calls getFile then file download)
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bot#{@bot_token}/getFile"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{"file_id" => "fid_doc", "file_path" => "documents/report2.pdf"}
        }))
      end)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/file/bot#{@bot_token}/documents/report2.pdf"

        conn
        |> Plug.Conn.put_resp_content_type("application/pdf")
        |> Plug.Conn.send_resp(200, "BINARY_PDF_DATA_2")
      end)

      assert {:ok, "BINARY_PDF_DATA_2"} = Client.download_file("fid_doc", token: @bot_token)
    end

    test "send_audio/2,3,4 client-first and direct delegation" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bot#{@bot_token}/sendAudio"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{"message_id" => 501}
        }))
      end)

      assert {:ok, resp} = Client.send_audio(client, 123, "https://example.com/sound.mp3")
      assert resp["ok"] == true
    end

    test "send_video/2,3,4 client-first and direct delegation" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bot#{@bot_token}/sendVideo"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{"message_id" => 502}
        }))
      end)

      assert {:ok, resp} = Client.send_video(client, 123, "https://example.com/clip.mp4")
      assert resp["ok"] == true
    end
  end

  describe "mock isolation & plug preservation" do
    test "custom plug option is preserved across request dispatch without hitting network" do
      custom_plug = fn conn ->
        assert conn.request_path == "/botcustom_token/getMe"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{"id" => 777, "username" => "custom_mock_bot"}
        }))
      end

      assert {:ok, resp} = Client.request(:get, "/getMe", token: "custom_token", plug: custom_plug)
      assert resp["result"]["username"] == "custom_mock_bot"
    end

    test "log_out/1 and close/1" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/logOut"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, _} = Client.log_out(client)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/close"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, _} = Client.close(client)
    end

    test "set_webhook/3 with client, url, opts and url-first overload" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/setWebhook"
        {:ok, body, _} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["url"] == "https://example.com/wh"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, _} = Client.set_webhook(client, "https://example.com/wh", drop_pending_updates: true)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/setWebhook"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, _} = Client.set_webhook("https://example.com/wh", [token: @bot_token], token: @bot_token)
    end

    test "delete_webhook/2 with client and opts" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/deleteWebhook"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, _} = Client.delete_webhook(client, drop_pending_updates: true)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/deleteWebhook"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, _} = Client.delete_webhook([token: @bot_token], [])
    end

    test "messaging delegates and overloads" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/sendMessage"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1}}))
      end)

      assert {:ok, _} = Client.send_message(client, 123, "hello", %{})

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/editMessageText"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, _} = Client.edit_message_text(client, 123, 1, "edit")

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/deleteMessage"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, _} = Client.delete_message(client, 123, 1)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/copyMessage"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 2}}))
      end)

      assert {:ok, _} = Client.copy_message(client, 123, 456, 1)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/forwardMessage"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 3}}))
      end)

      assert {:ok, _} = Client.forward_message(client, 123, 456, 1)
    end

    test "media delegates and overloads" do
      client = Client.new(@bot_token)

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/sendPhoto"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1}}))
      end)

      assert {:ok, _} = Client.send_photo(client, 123, "http://example.com/p.png")

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/sendDocument"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 2}}))
      end)

      assert {:ok, _} = Client.send_document(client, 123, "http://example.com/doc.pdf")

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/sendVoice"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 3}}))
      end)

      assert {:ok, _} = Client.send_voice(client, 123, "http://example.com/v.ogg")
    end

    test "Inspect protocol redacts token" do
      client = Client.new("sensitive_secret_token_123")
      inspected = inspect(client)
      refute String.contains?(inspected, "sensitive_secret_token_123")
      assert String.contains?(inspected, "[REDACTED]")
    end
  end

  describe "resolve_token/1 token resolution rules" do
    test "resolves token from atom key map and keyword list" do
      assert Client.resolve_token(%{token: "map_tok"}) == "map_tok"
      assert Client.resolve_token([token: "kw_tok"]) == "kw_tok"
    end

    test "resolves token from Application config and System ENV" do
      orig_keys = Application.get_env(:lux, :api_keys, [])
      try do
        Application.put_env(:lux, :api_keys, [telegram_bot: "cfg_bot_token"])
        assert Client.resolve_token(nil) == "cfg_bot_token"

        Application.put_env(:lux, :api_keys, [])
        Application.put_env(:lux, :telegram_bot_token, "app_config_token")
        assert Client.resolve_token(nil) == "app_config_token"
        Application.delete_env(:lux, :telegram_bot_token)
      after
        Application.put_env(:lux, :api_keys, orig_keys)
      end
    end
  end

  describe "build_url/3 URL variants" do
    test "handles base_url with embedded /bot, empty base_url, and nil arguments" do
      assert Client.build_url("https://proxy.example.com/bot/api", "123", "/getMe") ==
               "https://proxy.example.com/bot/api/getMe"

      assert Client.build_url(nil, "123", "getMe") == "https://api.telegram.org/bot123/getMe"
      assert Client.build_url("", "123", "getMe") == "https://api.telegram.org/bot123/getMe"
      assert Client.build_url("https://api.telegram.org/bot", nil, nil) == "https://api.telegram.org/bot/"
    end
  end

  describe "request/2,3,4 payload types and error parsing" do
    test "request/2 2-arity dispatching" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/getMe"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{}}))
      end)

      assert {:ok, _} = Client.request(:get, "/getMe", token: @bot_token)
    end

    test "dispatches request with :params, :body, and clean query parameters" do
      # 1. :params
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.query_string == "offset=10"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true}))
      end)
      assert {:ok, _} = Client.request(:get, "/getUpdates", token: @bot_token, params: %{offset: 10})

      # 2. :body
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        assert body == "raw_data"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true}))
      end)
      assert {:ok, _} = Client.request(:post, "/test", token: @bot_token, body: "raw_data")

      # 3. clean GET params
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.query_string =~ "offset=5"
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true}))
      end)
      assert {:ok, _} = Client.request(:get, "/getUpdates", token: @bot_token, offset: 5)
    end

    test "handles HTTP 200 with ok: false and 500 non-description body" do
      # HTTP 200 with ok: false
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => false, "error" => "custom"}))
      end)
      assert {:error, %{"ok" => false}} = Client.request(:get, "/test", token: @bot_token)

      # 500 plain body
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("text/plain") |> Plug.Conn.send_resp(500, "Internal Error")
      end)
      assert {:error, {500, "Internal Error"}} = Client.request(:get, "/test", token: @bot_token, max_retries: 0)
    end

    test "handles 429 with atom map parameters" do
      custom_plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"parameters" => %{"retry_after" => 4}}))
      end

      assert {:error, {429, _}} = Client.request(:get, "/test", token: @bot_token, plug: custom_plug, max_rate_limit_retries: 0)
    end

    test "handles Req network exception" do
      bad_plug = fn _conn -> raise "Network cable unplugged" end
      assert {:error, %RuntimeError{message: "Network cable unplugged"}} =
               Client.request(:get, "/test", token: @bot_token, plug: bad_plug)
    end
  end

  describe "all delegated client functions coverage" do
    test "messaging helper overloads with and without opts" do
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1}}))
      end
      client_with_plug = Client.new(token: @bot_token, req_options: [plug: plug])

      assert {:ok, _} = Client.send_message(client_with_plug, 123, "hi")
      assert {:ok, _} = Client.send_message(123, "hi", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.edit_message_text(client_with_plug, 123, 1, "text", %{})
      assert {:ok, _} = Client.edit_message_text(123, 1, "text", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.delete_message(client_with_plug, 123, 1, %{})
      assert {:ok, _} = Client.delete_message(123, 1, token: @bot_token, plug: plug)
      assert {:ok, _} = Client.copy_message(client_with_plug, 123, 456, 1, %{})
      assert {:ok, _} = Client.copy_message(123, 456, 1, token: @bot_token, plug: plug)
      assert {:ok, _} = Client.forward_message(client_with_plug, 123, 456, 1, %{})
      assert {:ok, _} = Client.forward_message(123, 456, 1, token: @bot_token, plug: plug)
    end

    test "media helper overloads with and without opts" do
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1, "file_id" => "f1", "file_path" => "p1"}}))
      end
      client_with_plug = Client.new(token: @bot_token, req_options: [plug: plug])

      assert {:ok, _} = Client.send_photo(client_with_plug, 123, "photo_url", %{})
      assert {:ok, _} = Client.send_photo(123, "photo_url", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.send_document(client_with_plug, 123, "doc_url", %{})
      assert {:ok, _} = Client.send_document(123, "doc_url", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.send_voice(client_with_plug, 123, "voice_url", %{})
      assert {:ok, _} = Client.send_voice(123, "voice_url", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.send_audio(client_with_plug, 123, "audio_url", %{})
      assert {:ok, _} = Client.send_audio(123, "audio_url", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.send_video(client_with_plug, 123, "video_url", %{})
      assert {:ok, _} = Client.send_video(123, "video_url", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.get_file(client_with_plug, "f1", %{})
      assert {:ok, _} = Client.download_file(client_with_plug, "p1", %{})
    end

    test "bot management helpers with keyword / map options" do
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{}}))
      end

      assert {:ok, _} = Client.get_me(token: @bot_token, plug: plug)
      assert {:ok, _} = Client.log_out(token: @bot_token, plug: plug)
      assert {:ok, _} = Client.close(token: @bot_token, plug: plug)
      assert {:ok, _} = Client.get_webhook_info(token: @bot_token, plug: plug)
    end
  end

  describe "client convenience delegates without client struct" do
    test "2/3/4 arity messaging and media delegates" do
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1, "file_id" => "f1", "file_path" => "p1"}}))
      end
      client = Client.new(token: @bot_token, req_options: [plug: plug])

      # 4-arity messaging with client
      assert {:ok, _} = Client.send_message(client, 123, "hi", %{})
      assert {:ok, _} = Client.edit_message_text(client, 123, 1, "hi", %{})
      assert {:ok, _} = Client.delete_message(client, 123, 1, %{})
      assert {:ok, _} = Client.copy_message(client, 123, 456, 1, %{})
      assert {:ok, _} = Client.forward_message(client, 123, 456, 1, %{})

      # 2/3-arity messaging delegates
      assert {:ok, _} = Client.send_message(123, "hi", [token: @bot_token, plug: plug])
      assert {:ok, _} = Client.send_message(123, "hi", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.edit_message_text(123, 1, "hi", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.delete_message(123, 1, token: @bot_token, plug: plug)
      assert {:ok, _} = Client.copy_message(123, 456, 1, token: @bot_token, plug: plug)
      assert {:ok, _} = Client.forward_message(123, 456, 1, token: @bot_token, plug: plug)

      # 4-arity media with client
      assert {:ok, _} = Client.send_photo(client, 123, "photo", %{})
      assert {:ok, _} = Client.send_document(client, 123, "doc", %{})
      assert {:ok, _} = Client.send_voice(client, 123, "voice", %{})
      assert {:ok, _} = Client.send_audio(client, 123, "audio", %{})
      assert {:ok, _} = Client.send_video(client, 123, "video", %{})
      assert {:ok, _} = Client.get_file(client, "f1", %{})
      assert {:ok, _} = Client.download_file(client, "p1", %{})

      # 2/3-arity media delegates
      assert {:ok, _} = Client.send_photo(123, "photo", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.send_document(123, "doc", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.send_voice(123, "voice", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.send_audio(123, "audio", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.send_video(123, "video", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.get_file("f1", token: @bot_token, plug: plug)
      assert {:ok, _} = Client.download_file("p1", token: @bot_token, plug: plug)

      # Default 0-arity or options-less helpers
      assert {:ok, _} = Client.get_me(plug: plug, token: @bot_token)
      assert {:ok, _} = Client.get_webhook_info(plug: plug, token: @bot_token)
      assert {:ok, _} = Client.delete_webhook(plug: plug, token: @bot_token)
      assert {:ok, _} = Client.log_out(plug: plug, token: @bot_token)
      assert {:ok, _} = Client.close(plug: plug, token: @bot_token)
    end

    test "request/4 with keyword / map client options and form multipart" do
      tmp = Path.join(System.tmp_dir!(), "lux_client_tmp_#{System.unique_integer([:positive, :monotonic])}.txt")
      File.write!(tmp, "hello")
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{}}))
      end

      assert {:ok, _} = Client.request([token: @bot_token, req_options: [plug: plug]], :post, "/test", form_multipart: [file: {:file, tmp}])
      assert {:ok, _} = Client.request(%{token: @bot_token, req_options: [plug: plug]}, :post, "/test", form: %{file: {:file, tmp}})
      assert {:ok, _} = Client.request(%{token: @bot_token, req_options: [plug: plug]}, :get, "/test", %{file: {:file, tmp}})
      assert {:ok, _} = Client.request(%{token: @bot_token, req_options: [plug: plug]}, :post, "/test", [query: "param"])
      assert {:ok, _} = Client.request(:get, "/test", token: @bot_token, plug: plug)

      # Test maybe_remove_json_content_type when headers have Content-Type: application/json
      assert {:ok, _} = Client.request([token: @bot_token, req_options: [plug: plug]], :post, "/test", [
        headers: [{"content-type", "application/json"}, {"authorization", "Bearer 123"}],
        form: %{file: {:file, tmp}}
      ])
      assert {:ok, _} = Client.request([token: @bot_token, req_options: [plug: plug]], :post, "/test", [
        headers: [{"content-type", "application/json"}],
        form: %{file: {:file, tmp}}
      ])

      File.rm(tmp)
    end

    test "set_webhook and delete_webhook overloads" do
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end
      client = Client.new(token: @bot_token, req_options: [plug: plug])

      # set_webhook variants
      assert {:ok, _} = Client.set_webhook("https://example.com/hook", [token: @bot_token, plug: plug], %{extra: 1})
      assert {:ok, _} = Client.set_webhook("https://example.com/hook", [token: @bot_token, plug: plug], [])
      assert {:ok, _} = Client.set_webhook(client, "https://example.com/hook", [drop_pending_updates: true])

      # delete_webhook variants
      assert {:ok, _} = Client.delete_webhook(client, [drop_pending_updates: true])
      assert {:ok, _} = Client.delete_webhook([token: @bot_token, plug: plug], [drop_pending_updates: true])
      assert {:ok, _} = Client.delete_webhook([drop_pending_updates: true], [token: @bot_token, plug: plug])
      assert {:ok, _} = Client.delete_webhook(%{token: @bot_token, plug: plug})
    end

    test "Inspect protocol on client with nil token" do
      client_no_token = %Client{token: nil, base_url: "https://api.telegram.org/bot", req_options: []}
      inspected = inspect(client_no_token)
      refute String.contains?(inspected, "[REDACTED]")
    end

    test "client delegates without options and with default client" do
      orig_keys = Application.get_env(:lux, :api_keys, [])
      try do
        Application.put_env(:lux, :api_keys, [telegram_bot: @bot_token])
        Req.Test.expect(TelegramClientMock, 15, fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1, "file_path" => "p.jpg"}}))
        end)

        # 2-arity messaging
        assert {:ok, _} = Client.send_message(123, "hello")
        assert {:ok, _} = Client.edit_message_text(123, 1, "hello")
        assert {:ok, _} = Client.delete_message(123, 1)
        assert {:ok, _} = Client.copy_message(123, 456, 1)
        assert {:ok, _} = Client.forward_message(123, 456, 1)

        # 2-arity media
        assert {:ok, _} = Client.send_photo(123, "photo")
        assert {:ok, _} = Client.send_document(123, "doc")
        assert {:ok, _} = Client.send_voice(123, "voice")
        assert {:ok, _} = Client.send_audio(123, "audio")
        assert {:ok, _} = Client.send_video(123, "video")
        assert {:ok, _} = Client.get_file("f1")
        assert {:ok, _} = Client.download_file("photos/p.jpg")

        # 0-arity
        assert {:ok, _} = Client.get_me()
        assert {:ok, _} = Client.log_out()
        assert {:ok, _} = Client.close()
      after
        Application.put_env(:lux, :api_keys, orig_keys)
      end
    end

    test "3-arity media delegates with client struct" do
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"file_path" => "photos/p.jpg"}}))
      end
      client = Client.new(token: @bot_token, req_options: [plug: plug])

      assert {:ok, _} = Client.send_photo(client, 123, "photo")
      assert {:ok, _} = Client.send_document(client, 123, "doc")
      assert {:ok, _} = Client.send_voice(client, 123, "voice")
      assert {:ok, _} = Client.send_audio(client, 123, "audio")
      assert {:ok, _} = Client.send_video(client, 123, "video")
      assert {:ok, _} = Client.get_file(client, "f1")
      assert {:ok, _} = Client.download_file(client, "photos/p.jpg")
    end

    test "webhook helper functions with client and with options" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      client = Client.new(token: @bot_token, req_options: [plug: plug])
      assert {:ok, _} = Client.set_webhook(client, "https://example.com/webhook", [])
      assert {:ok, _} = Client.set_webhook("https://example.com/webhook", [token: @bot_token, plug: plug], %{})
      assert {:ok, _} = Client.set_webhook("https://example.com/webhook", [token: @bot_token, plug: plug], [token: @bot_token, plug: plug])
      assert {:ok, _} = Client.delete_webhook(client, [])
      assert {:ok, _} = Client.delete_webhook([token: @bot_token, plug: plug], [])
      assert {:ok, _} = Client.delete_webhook([plug: plug], [])
      assert {:ok, _} = Client.get_webhook_info(client)
    end

    test "request/2,3,4 with client map options and 2-arity" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{}}))
      end

      client = Client.new(token: @bot_token, req_options: [plug: plug])
      assert {:ok, _} = Client.request(client, :get, "/getMe")
      assert {:ok, _} = Client.request(%{token: @bot_token}, :get, "/getMe", [plug: plug])
      assert {:ok, _} = Client.request([token: @bot_token], :get, "/getMe", [plug: plug])
    end

    test "request with :params, :body, and clean query parameters" do
      test_pid = self()

      # 1. :params
      plug_params = fn conn ->
        send(test_pid, {:query, conn.query_string})
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true}))
      end
      assert {:ok, _} = Client.request(:get, "/getUpdates", token: @bot_token, plug: plug_params, params: %{offset: 10})
      assert_receive {:query, "offset=10"}

      # 2. :body
      plug_body = fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        send(test_pid, {:body, body})
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true}))
      end
      assert {:ok, _} = Client.request(:post, "/test", token: @bot_token, plug: plug_body, body: "raw_data")
      assert_receive {:body, "raw_data"}

      # 3. clean GET params
      plug_clean = fn conn ->
        send(test_pid, {:clean_query, conn.query_string})
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true}))
      end
      assert {:ok, _} = Client.request(:get, "/getUpdates", token: @bot_token, plug: plug_clean, offset: 5)
      assert_receive {:clean_query, query}
      assert query =~ "offset=5"
    end

    test "handles HTTP 200 with ok: false and 500 non-description body" do
      # HTTP 200 with ok: false
      plug_false = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => false, "error" => "custom"}))
      end
      assert {:error, %{"ok" => false}} = Client.request(:get, "/test", token: @bot_token, plug: plug_false)

      # 200 plain non-map body
      plug_plain_ok = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("text/plain") |> Plug.Conn.send_resp(200, "OK")
      end
      assert {:ok, "OK"} = Client.request(:get, "/test", token: @bot_token, plug: plug_plain_ok)

      # 400 description body
      plug_400 = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(400, Jason.encode!(%{"description" => "Bad Request"}))
      end
      assert {:error, {400, "Bad Request"}} = Client.request(:get, "/test", token: @bot_token, plug: plug_400)

      # 401 unauthorized
      plug_401 = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(401, Jason.encode!(%{"ok" => false}))
      end
      assert {:error, :invalid_token} = Client.request(:get, "/test", token: @bot_token, plug: plug_401)

      # 500 plain body
      plug_500 = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("text/plain") |> Plug.Conn.send_resp(500, "Internal Error")
      end
      assert {:error, {500, "Internal Error"}} = Client.request(:get, "/test", token: @bot_token, plug: plug_500)
    end

    test "handles 429 with atom map parameters and Req exception" do
      custom_plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"parameters" => %{"retry_after" => 4}}))
      end

      assert {:error, {429, _}} = Client.request(:get, "/test", token: @bot_token, plug: custom_plug, max_rate_limit_retries: 0)

      bad_plug = fn _conn -> raise "Network cable unplugged" end
      assert {:error, %RuntimeError{message: "Network cable unplugged"}} =
               Client.request(:get, "/test", token: @bot_token, plug: bad_plug)
    end
  end

  describe "client edge cases and full branch coverage" do
    test "resolve_token directly with non-empty string and fallback rescue" do
      assert Client.resolve_token("direct_token_string") == "direct_token_string"
      assert Client.resolve_token("") != ""
    end

    test "request/4 with client keyword options, 2-arity request/2, and form_multipart payload" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{}}))
      end

      assert {:ok, _} = Client.request([token: @bot_token, req_options: [plug: plug]], :get, "/getMe", [])
      assert {:ok, _} = Client.request([token: @bot_token, req_options: [plug: plug]], :post, "/test", form_multipart: [field: "val"])
      assert {:ok, _} = Client.request(:get, "/getMe", token: @bot_token, plug: plug)
    end

    test "parse_response handles 429 with atom map parameters and Req exception" do
      plug_429 = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{parameters: %{retry_after: 5}}))
      end
      assert {:error, {429, _}} = Client.request(:get, "/test", token: @bot_token, plug: plug_429, max_rate_limit_retries: 0)

      bad_plug = fn _conn -> raise "Req failure" end
      assert {:error, %RuntimeError{message: "Req failure"}} = Client.request(:get, "/test", token: @bot_token, plug: bad_plug)
    end

    test "maybe_remove_json_content_type and is_form_or_file_value? variants" do
      tmp = Path.join(System.tmp_dir!(), "lux_client_tmp2_#{System.unique_integer([:positive, :monotonic])}.txt")
      File.write!(tmp, "hello")

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{}}))
      end

      # Form with stream struct and opts
      stream = File.stream!(tmp)
      assert {:ok, _} = Client.request([token: @bot_token, req_options: [plug: plug]], :post, "/test", form: %{f1: stream, f2: {stream, filename: "t.txt"}, f3: {"data", filename: "d.txt"}})
      assert {:ok, _} = Client.request([token: @bot_token, req_options: [plug: plug]], :post, "/test", form_multipart: [{:f1, {:file, tmp}}])

      File.rm(tmp)
    end

    test "bot management error and non-map response branches" do
      # get_me returning non-map or error
      plug_non_map = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(true))
      end
      assert {:ok, true} = Client.get_me(token: @bot_token, plug: plug_non_map)

      plug_err = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(400, Jason.encode!(%{"ok" => false, "description" => "Bad"}))
      end
      assert {:error, {400, "Bad"}} = Client.get_me(token: @bot_token, plug: plug_err)

      # get_webhook_info returning non-map or error
      assert {:ok, true} = Client.get_webhook_info(token: @bot_token, plug: plug_non_map)
      assert {:error, {400, "Bad"}} = Client.get_webhook_info(token: @bot_token, plug: plug_err)

      # delete_webhook with empty options
      assert {:ok, _} = Client.delete_webhook([], token: @bot_token, plug: plug_non_map)
    end

    test "all 2-arity messaging and media delegates" do
      orig_keys = Application.get_env(:lux, :api_keys, [])
      try do
        Application.put_env(:lux, :api_keys, [telegram_bot: @bot_token])
        Req.Test.expect(TelegramClientMock, 12, fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1, "file_path" => "photos/p.jpg"}}))
        end)

        assert {:ok, _} = Client.send_message(123, "hi")
        assert {:ok, _} = Client.edit_message_text(123, 1, "hi")
        assert {:ok, _} = Client.delete_message(123, 1)
        assert {:ok, _} = Client.copy_message(123, 456, 1)
        assert {:ok, _} = Client.forward_message(123, 456, 1)

        assert {:ok, _} = Client.send_photo(123, "photo")
        assert {:ok, _} = Client.send_document(123, "doc")
        assert {:ok, _} = Client.send_voice(123, "voice")
        assert {:ok, _} = Client.send_audio(123, "audio")
        assert {:ok, _} = Client.send_video(123, "video")
        assert {:ok, _} = Client.get_file("fid")
        assert {:ok, _} = Client.download_file("photos/p.jpg")
      after
        Application.put_env(:lux, :api_keys, orig_keys)
      end
    end
  end
end




