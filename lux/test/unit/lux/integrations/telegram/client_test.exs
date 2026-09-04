defmodule Lux.Integrations.Telegram.ClientTest do
  use UnitAPICase, async: false

  alias Lux.Integrations.Telegram.Client

  @bot_token "test_bot_token"
  @mock_api_key "mock_token:ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"

  import Mock

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "request/3" do
    test "makes correct API call for GET request" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/bottest_bot_token/getMe"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "id" => 123_456_789,
            "is_bot" => true,
            "first_name" => "TestBot",
            "username" => "test_bot"
          }
        }))
      end)

      {:ok, response} =
        Client.request(:get, "/getMe", %{
          token: @bot_token
        })

      assert response["ok"] == true
      assert get_in(response, ["result", "username"]) == "test_bot"
    end

    test "makes correct API call for POST request with JSON body" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bottest_bot_token/sendMessage"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        body_params = Jason.decode!(body)
        assert body_params["chat_id"] == 123_456_789
        assert body_params["text"] == "Hello, world!"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => 456,
            "chat" => %{"id" => 123_456_789}
          }
        }))
      end)

      {:ok, response} =
        Client.request(:post, "/sendMessage", %{
          token: @bot_token,
          json: %{
            chat_id: 123_456_789,
            text: "Hello, world!"
          }
        })

      assert response["ok"] == true
      assert get_in(response, ["result", "message_id"]) == 456
    end

    test "uses configured API key when token is not provided" do
      api_key = @mock_api_key

      with_mock Lux.Config, [:passthrough], [telegram_bot_token: fn -> api_key end] do
        Req.Test.expect(TelegramClientMock, fn conn ->
          assert conn.method == "GET"
          assert conn.request_path == "/bot#{api_key}/getMe"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "id" => 123_456_789,
              "is_bot" => true,
              "first_name" => "TestBot",
              "username" => "test_bot"
            }
          }))
        end)

        {:ok, response} =
          Client.request(:get, "/getMe")

        assert response["ok"] == true
        assert get_in(response, ["result", "username"]) == "test_bot"
      end
    end

    test "handles 401 authentication error" do
      token = "invalid_token"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/bot#{token}/getMe"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "ok" => false,
          "error_code" => 401,
          "description" => "Unauthorized"
        }))
      end)

      {:error, :invalid_token} =
        Client.request(:get, "/getMe", %{
          token: token
        })
    end

    test "handles 400 API error with description" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bottest_bot_token/sendMessage"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "error_code" => 400,
          "description" => "Bad Request: chat not found"
        }))
      end)

      {:error, {400, "Bad Request: chat not found"}} =
        Client.request(:post, "/sendMessage", %{
          token: @bot_token,
          json: %{
            chat_id: 123_456_789,
            text: "Hello, world!"
          }
        })
    end

    test "handles 403 Forbidden error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "ok" => false,
          "error_code" => 403,
          "description" => "Forbidden: bot was blocked by the user"
        }))
      end)

      {:error, {403, "Forbidden: bot was blocked by the user"}} =
        Client.request(:post, "/sendMessage", %{
          token: @bot_token,
          json: %{chat_id: 999, text: "hi"}
        })
    end

    test "handles 404 Not Found error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "ok" => false,
          "error_code" => 404,
          "description" => "Not Found"
        }))
      end)

      {:error, {404, "Not Found"}} =
        Client.request(:get, "/invalidEndpoint", %{token: @bot_token})
    end

    test "handles 429 Too Many Requests error with retry_after" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests: retry after 5",
          "parameters" => %{"retry_after" => 5}
        }))
      end)

      {:error, {429, body}} =
        Client.request(:get, "/getMe", %{
          token: @bot_token,
          max_rate_limit_retries: 0
        })

      assert body["parameters"]["retry_after"] == 5
    end

    test "handles 500 Internal Server Error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{
          "ok" => false,
          "error_code" => 500,
          "description" => "Internal Server Error"
        }))
      end)

      {:error, {500, "Internal Server Error"}} =
        Client.request(:get, "/getMe", %{token: @bot_token, max_retries: 0})
    end

    test "handles unexpected response format" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "unexpected" => "format"
        }))
      end)

      {:error, body} =
        Client.request(:get, "/getMe", %{token: @bot_token})

      assert body == %{"unexpected" => "format"}
    end
  end

  describe "get_file/2" do
    test "fetches file info by file_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bot#{@bot_token}/getFile"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["file_id"] == "file_abc_123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "file_id" => "file_abc_123",
            "file_unique_id" => "unique_123",
            "file_size" => 4096,
            "file_path" => "photos/file_0.jpg"
          }
        }))
      end)

      assert {:ok, resp} = Client.get_file("file_abc_123", token: @bot_token)
      assert resp["ok"] == true
      assert resp["result"]["file_path"] == "photos/file_0.jpg"
    end
  end

  describe "download_file/2" do
    test "downloads file directly when given a file_path containing slashes" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/file/bot#{@bot_token}/photos/avatar.png"

        conn
        |> Plug.Conn.put_resp_content_type("image/png")
        |> Plug.Conn.send_resp(200, "PNG_BINARY_CONTENT_DATA")
      end)

      assert {:ok, "PNG_BINARY_CONTENT_DATA"} =
               Client.download_file("photos/avatar.png", token: @bot_token)
    end

    test "downloads file by file_id resolving get_file first" do
      # 1. Expect getFile POST
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bot#{@bot_token}/getFile"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "file_id" => "file_id_xyz",
            "file_path" => "documents/invoice.pdf"
          }
        }))
      end)

      # 2. Expect download GET
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/file/bot#{@bot_token}/documents/invoice.pdf"

        conn
        |> Plug.Conn.put_resp_content_type("application/pdf")
        |> Plug.Conn.send_resp(200, "%PDF-1.4-BINARY-DATA")
      end)

      assert {:ok, "%PDF-1.4-BINARY-DATA"} =
               Client.download_file("file_id_xyz", token: @bot_token)
    end

    test "returns error if get_file fails during file_id resolution" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bot#{@bot_token}/getFile"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "ok" => false,
          "error_code" => 404,
          "description" => "Bad Request: file not found"
        }))
      end)

      assert {:error, {404, "Bad Request: file not found"}} =
               Client.download_file("missing_file_id", token: @bot_token)
    end

    test "handles 429 with atom map, 500 without description, and network exceptions" do
      plug_429 = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(429, Jason.encode!(%{parameters: %{retry_after: 5}}))
      end
      assert {:error, {429, _}} = Client.request(:get, "/test", %{token: @bot_token, plug: plug_429})

      plug_500 = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("text/plain") |> Plug.Conn.send_resp(500, "Server Failure")
      end
      assert {:error, {500, "Server Failure"}} = Client.request(:get, "/test", %{token: @bot_token, plug: plug_500})

      bad_plug = fn _conn -> raise "Network disconnect" end
      assert {:error, %RuntimeError{message: "Network disconnect"}} = Client.request(:get, "/test", %{token: @bot_token, plug: bad_plug})

      plug_ok = fn conn ->
        case conn.request_path do
          "/bottest_bot_token/getFile" ->
            conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"file_path" => "photos/f.jpg"}}))
          "/file/bottest_bot_token/photos/f.jpg" ->
            conn |> Plug.Conn.put_resp_content_type("image/jpeg") |> Plug.Conn.send_resp(200, "file_data")
        end
      end
      assert {:ok, _} = Client.get_file("f1", %{token: @bot_token, plug: plug_ok})
      assert {:ok, "file_data"} = Client.download_file("f1", %{token: @bot_token, plug: plug_ok})
    end
  end
end

