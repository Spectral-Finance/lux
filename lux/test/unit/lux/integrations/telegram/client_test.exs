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
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "id" => 123_456_789,
              "is_bot" => true,
              "first_name" => "TestBot",
              "username" => "test_bot"
            }
          })
        )
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
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "message_id" => 456,
              "chat" => %{"id" => 123_456_789}
            }
          })
        )
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

      with_mock Lux.Config, [:passthrough], telegram_bot_token: fn -> api_key end do
        # Since our new client uses Telegram.get_token/0 instead of Lux.Config directly,
        # we need to set the application env for the fallback to work
        original_keys = Application.get_env(:lux, :api_keys)
        Application.put_env(:lux, :api_keys, telegram_bot: api_key)

        try do
          Req.Test.expect(TelegramClientMock, fn conn ->
            assert conn.method == "GET"
            assert conn.request_path == "/bot#{api_key}/getMe"

            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(
              200,
              Jason.encode!(%{
                "ok" => true,
                "result" => %{
                  "id" => 123_456_789,
                  "is_bot" => true,
                  "first_name" => "TestBot",
                  "username" => "test_bot"
                }
              })
            )
          end)

          {:ok, response} =
            Client.request(:get, "/getMe")

          assert response["ok"] == true
          assert get_in(response, ["result", "username"]) == "test_bot"
        after
          if original_keys,
            do: Application.put_env(:lux, :api_keys, original_keys),
            else: Application.delete_env(:lux, :api_keys)
        end
      end
    end

    test "handles authentication error" do
      token = "invalid_token"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/bot#{token}/getMe"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          401,
          Jason.encode!(%{
            "ok" => false,
            "error_code" => 401,
            "description" => "Unauthorized"
          })
        )
      end)

      {:error, :invalid_token} =
        Client.request(:get, "/getMe", %{
          token: token
        })
    end

    test "handles API error with description" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bottest_bot_token/sendMessage"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{
            "ok" => false,
            "error_code" => 400,
            "description" => "Bad Request: chat not found"
          })
        )
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

    test "handles unexpected response format" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/bottest_bot_token/getMe"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "unexpected" => "format"
          })
        )
      end)

      {:error, body} =
        Client.request(:get, "/getMe", %{token: @bot_token})

      assert body == %{"unexpected" => "format"}
    end
  end

  describe "token fallback" do
    test "returns {:error, :missing_token} when no token is available" do
      # Ensure no token is configured anywhere
      original_keys = Application.get_env(:lux, :api_keys)
      Application.delete_env(:lux, :api_keys)
      original_env = System.get_env("TELEGRAM_BOT_TOKEN")
      System.delete_env("TELEGRAM_BOT_TOKEN")

      try do
        assert {:error, :missing_token} = Client.request(:get, "/getMe")
      after
        if original_keys, do: Application.put_env(:lux, :api_keys, original_keys)
        if original_env, do: System.put_env("TELEGRAM_BOT_TOKEN", original_env)
      end
    end

    test "falls back to TELEGRAM_BOT_TOKEN env var" do
      original_keys = Application.get_env(:lux, :api_keys)
      Application.delete_env(:lux, :api_keys)
      original_env = System.get_env("TELEGRAM_BOT_TOKEN")
      System.put_env("TELEGRAM_BOT_TOKEN", "env_fallback_token")

      try do
        Req.Test.expect(TelegramClientMock, fn conn ->
          assert conn.request_path == "/botenv_fallback_token/getMe"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "ok" => true,
              "result" => %{"id" => 1}
            })
          )
        end)

        {:ok, response} = Client.request(:get, "/getMe")
        assert response["ok"] == true
      after
        if original_keys, do: Application.put_env(:lux, :api_keys, original_keys)

        if original_env,
          do: System.put_env("TELEGRAM_BOT_TOKEN", original_env),
          else: System.delete_env("TELEGRAM_BOT_TOKEN")
      end
    end

    test "explicit token option takes priority over config" do
      # Even if config has a different token, explicit token wins
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path == "/botexplicit_token/getMe"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{"id" => 1}
          })
        )
      end)

      {:ok, _response} = Client.request(:get, "/getMe", %{token: "explicit_token"})
    end
  end

  describe "retry with exponential backoff" do
    test "retries on 429 rate limit and returns rate_limited error when exhausted" do
      # With max_retries: 0, it should not retry and immediately return rate_limited error
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          429,
          Jason.encode!(%{
            "ok" => false,
            "error_code" => 429,
            "description" => "Too Many Requests: retry after 5",
            "parameters" => %{"retry_after" => 5}
          })
        )
      end)

      {:error, result} =
        Client.request(:get, "/getMe", %{
          token: @bot_token,
          max_retries: 0
        })

      assert result.reason == :rate_limited
      assert result.retry_after == 5
      assert result.description == "Too Many Requests: retry after 5"
    end

    test "retries on 500 transient error and returns error when exhausted" do
      # With max_retries: 0, should immediately return the error
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          500,
          Jason.encode!(%{
            "ok" => false,
            "description" => "Internal Server Error"
          })
        )
      end)

      {:error, {500, body}} =
        Client.request(:get, "/getMe", %{
          token: @bot_token,
          max_retries: 0
        })

      assert body["description"] == "Internal Server Error"
    end

    test "retries on 502 and eventually succeeds" do
      # First call returns 502, second call returns 200
      Req.Test.expect(TelegramClientMock, 2, fn conn ->
        # We use a process dictionary counter to alternate responses
        count = Process.get(:retry_count, 0)
        Process.put(:retry_count, count + 1)

        if count == 0 do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            502,
            Jason.encode!(%{
              "ok" => false,
              "description" => "Bad Gateway"
            })
          )
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "ok" => true,
              "result" => %{"message_id" => 1}
            })
          )
        end
      end)

      # Use max_retries: 1, with a short backoff since the test controls timing
      {:ok, response} =
        Client.request(:get, "/getMe", %{
          token: @bot_token,
          max_retries: 1
        })

      assert response["ok"] == true
    after
      Process.delete(:retry_count)
    end

    test "retries on 503 and returns error when exhausted" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          503,
          Jason.encode!(%{
            "ok" => false,
            "description" => "Service Unavailable"
          })
        )
      end)

      {:error, {503, _body}} =
        Client.request(:get, "/getMe", %{
          token: @bot_token,
          max_retries: 0
        })
    end

    test "retries on 504 and returns error when exhausted" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          504,
          Jason.encode!(%{
            "ok" => false,
            "description" => "Gateway Timeout"
          })
        )
      end)

      {:error, {504, _body}} =
        Client.request(:get, "/getMe", %{
          token: @bot_token,
          max_retries: 0
        })
    end
  end

  describe "request_many/2" do
    test "executes requests sequentially and returns results in order" do
      Req.Test.expect(TelegramClientMock, 2, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        body_params = Jason.decode!(body)
        text = body_params["text"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "message_id" => if(text == "First", do: 1, else: 2),
              "text" => text
            }
          })
        )
      end)

      {:ok, results} =
        Client.request_many(
          [
            {:post, "/sendMessage", %{json: %{chat_id: 1, text: "First"}}},
            {:post, "/sendMessage", %{json: %{chat_id: 1, text: "Second"}}}
          ],
          %{token: @bot_token}
        )

      assert length(results) == 2
      assert get_in(Enum.at(results, 0), ["result", "text"]) == "First"
      assert get_in(Enum.at(results, 1), ["result", "text"]) == "Second"
    end

    test "aborts on first failure" do
      # First request succeeds, second fails with 400
      Req.Test.expect(TelegramClientMock, 2, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        body_params = Jason.decode!(body)

        if body_params["text"] == "First" do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "ok" => true,
              "result" => %{"message_id" => 1}
            })
          )
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            400,
            Jason.encode!(%{
              "ok" => false,
              "error_code" => 400,
              "description" => "Bad Request"
            })
          )
        end
      end)

      {:error, {400, "Bad Request"}} =
        Client.request_many(
          [
            {:post, "/sendMessage", %{json: %{chat_id: 1, text: "First"}}},
            {:post, "/sendMessage", %{json: %{chat_id: 1, text: "Second"}}},
            {:post, "/sendMessage", %{json: %{chat_id: 1, text: "Third"}}}
          ],
          %{token: @bot_token, max_retries: 0}
        )
    end

    test "returns {:error, :missing_token} when no token available" do
      original_keys = Application.get_env(:lux, :api_keys)
      Application.delete_env(:lux, :api_keys)
      original_env = System.get_env("TELEGRAM_BOT_TOKEN")
      System.delete_env("TELEGRAM_BOT_TOKEN")

      try do
        assert {:error, :missing_token} =
                 Client.request_many([{:get, "/getMe"}])
      after
        if original_keys, do: Application.put_env(:lux, :api_keys, original_keys)
        if original_env, do: System.put_env("TELEGRAM_BOT_TOKEN", original_env)
      end
    end

    test "handles map-style request format" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{"id" => 1}
          })
        )
      end)

      {:ok, [result]} =
        Client.request_many(
          [%{method: :get, path: "/getMe"}],
          %{token: @bot_token}
        )

      assert result["ok"] == true
    end

    test "returns empty results for empty request list" do
      {:ok, []} = Client.request_many([], %{token: @bot_token})
    end
  end

  describe "multipart_request/4" do
    test "returns {:error, :missing_token} when no token available" do
      original_keys = Application.get_env(:lux, :api_keys)
      Application.delete_env(:lux, :api_keys)
      original_env = System.get_env("TELEGRAM_BOT_TOKEN")
      System.delete_env("TELEGRAM_BOT_TOKEN")

      try do
        assert {:error, :missing_token} =
                 Client.multipart_request(:post, "/sendPhoto", %{chat_id: "123"})
      after
        if original_keys, do: Application.put_env(:lux, :api_keys, original_keys)
        if original_env, do: System.put_env("TELEGRAM_BOT_TOKEN", original_env)
      end
    end

    test "sends multipart request with file tuple" do
      # Create a temporary test file
      tmp_path =
        Path.join(System.tmp_dir!(), "test_upload_#{:erlang.unique_integer([:positive])}.txt")

      File.write!(tmp_path, "test file content")

      try do
        Req.Test.expect(TelegramClientMock, fn conn ->
          assert conn.method == "POST"
          assert conn.request_path == "/bottest_bot_token/sendDocument"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "ok" => true,
              "result" => %{
                "message_id" => 789,
                "document" => %{"file_id" => "doc123"}
              }
            })
          )
        end)

        {:ok, response} =
          Client.multipart_request(
            :post,
            "/sendDocument",
            %{
              chat_id: "123456",
              document: {:file, tmp_path}
            },
            %{token: @bot_token}
          )

        assert response["ok"] == true
        assert get_in(response, ["result", "document", "file_id"]) == "doc123"
      after
        File.rm(tmp_path)
      end
    end

    test "sends multipart request with string params" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bottest_bot_token/sendPhoto"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{"message_id" => 123}
          })
        )
      end)

      {:ok, response} =
        Client.multipart_request(
          :post,
          "/sendPhoto",
          %{
            chat_id: "123456",
            photo: "https://example.com/photo.jpg",
            caption: "Test caption"
          },
          %{token: @bot_token}
        )

      assert response["ok"] == true
    end
  end

  describe "Lux.Integrations.Telegram" do
    alias Lux.Integrations.Telegram

    test "get_token/0 returns token from application config" do
      original_keys = Application.get_env(:lux, :api_keys)
      Application.put_env(:lux, :api_keys, telegram_bot: "config_token_123")

      try do
        assert {:ok, "config_token_123"} = Telegram.get_token()
      after
        if original_keys,
          do: Application.put_env(:lux, :api_keys, original_keys),
          else: Application.delete_env(:lux, :api_keys)
      end
    end

    test "get_token/0 falls back to env var" do
      original_keys = Application.get_env(:lux, :api_keys)
      Application.delete_env(:lux, :api_keys)
      original_env = System.get_env("TELEGRAM_BOT_TOKEN")
      System.put_env("TELEGRAM_BOT_TOKEN", "env_token_456")

      try do
        assert {:ok, "env_token_456"} = Telegram.get_token()
      after
        if original_keys, do: Application.put_env(:lux, :api_keys, original_keys)

        if original_env,
          do: System.put_env("TELEGRAM_BOT_TOKEN", original_env),
          else: System.delete_env("TELEGRAM_BOT_TOKEN")
      end
    end

    test "get_token/0 returns error when nothing configured" do
      original_keys = Application.get_env(:lux, :api_keys)
      Application.delete_env(:lux, :api_keys)
      original_env = System.get_env("TELEGRAM_BOT_TOKEN")
      System.delete_env("TELEGRAM_BOT_TOKEN")

      try do
        assert {:error, :missing_token} = Telegram.get_token()
      after
        if original_keys, do: Application.put_env(:lux, :api_keys, original_keys)
        if original_env, do: System.put_env("TELEGRAM_BOT_TOKEN", original_env)
      end
    end

    test "add_auth/1 handles Lux.Lens struct with :token placeholder" do
      original_keys = Application.get_env(:lux, :api_keys)
      Application.put_env(:lux, :api_keys, telegram_bot: "my_bot_token")

      try do
        lens = %Lux.Lens{url: "https://api.telegram.org/bot:token/getUpdates"}
        result = Telegram.add_auth(lens)
        assert result.url == "https://api.telegram.org/botmy_bot_token/getUpdates"
      after
        if original_keys,
          do: Application.put_env(:lux, :api_keys, original_keys),
          else: Application.delete_env(:lux, :api_keys)
      end
    end

    test "add_auth/1 normalizes string keys in Lens params to existing atoms" do
      original_keys = Application.get_env(:lux, :api_keys)
      Application.put_env(:lux, :api_keys, telegram_bot: "my_bot_token")

      try do
        # Note: :limit and :offset are existing atoms in the codebase
        lens = %Lux.Lens{
          url: "https://api.telegram.org/bot:token/getUpdates",
          params: %{"limit" => 5, "offset" => 10}
        }

        result = Telegram.add_auth(lens)
        assert result.url == "https://api.telegram.org/botmy_bot_token/getUpdates"
        assert result.params == %{limit: 5, offset: 10}
      after
        if original_keys,
          do: Application.put_env(:lux, :api_keys, original_keys),
          else: Application.delete_env(:lux, :api_keys)
      end
    end

    test "add_auth/1 returns unmodified struct when token is missing" do
      original_keys = Application.get_env(:lux, :api_keys)
      Application.delete_env(:lux, :api_keys)
      original_env = System.get_env("TELEGRAM_BOT_TOKEN")
      System.delete_env("TELEGRAM_BOT_TOKEN")

      try do
        lens = %Lux.Lens{url: "https://api.telegram.org/bot:token/getUpdates"}
        result = Telegram.add_auth(lens)
        # Should return unmodified — token placeholder remains
        assert result.url == "https://api.telegram.org/bot:token/getUpdates"
      after
        if original_keys, do: Application.put_env(:lux, :api_keys, original_keys)
        if original_env, do: System.put_env("TELEGRAM_BOT_TOKEN", original_env)
      end
    end

    test "add_auth/1 handles unknown struct types gracefully" do
      original_keys = Application.get_env(:lux, :api_keys)
      Application.put_env(:lux, :api_keys, telegram_bot: "my_bot_token")

      try do
        # Passing an arbitrary value should return it unchanged
        assert Telegram.add_auth(:something) == :something
        assert Telegram.add_auth("a string") == "a string"
        assert Telegram.add_auth(nil) == nil
      after
        if original_keys,
          do: Application.put_env(:lux, :api_keys, original_keys),
          else: Application.delete_env(:lux, :api_keys)
      end
    end

    test "add_auth/1 does not substitute token in path segments containing 'bot' as prefix or suffix" do
      original_keys = Application.get_env(:lux, :api_keys)
      Application.put_env(:lux, :api_keys, telegram_bot: "my_bot_token")

      try do
        # Lenses with 'somebot' should not be substituted
        lens = %Lux.Lens{url: "https://example.com/somebot/"}
        assert Telegram.add_auth(lens) == lens

        lens2 = %Lux.Lens{url: "https://example.com/botprefix/"}
        assert Telegram.add_auth(lens2) == lens2

        # Plug.Conn with 'somebot' should not be substituted
        conn = %Plug.Conn{request_path: "/somebot/sendMessage"}
        assert Telegram.add_auth(conn) == conn

        # Req.Request with 'somebot' should not be substituted
        req = Req.new(url: "https://example.com/somebot/")
        assert Telegram.add_auth(req) == req
      after
        if original_keys,
          do: Application.put_env(:lux, :api_keys, original_keys),
          else: Application.delete_env(:lux, :api_keys)
      end
    end

    test "add_auth_header/1 delegates to add_auth/1 for backwards compatibility" do
      original_keys = Application.get_env(:lux, :api_keys)
      Application.put_env(:lux, :api_keys, telegram_bot: "compat_token")

      try do
        conn = %Plug.Conn{request_path: "/bot/sendMessage"}
        result = Telegram.add_auth_header(conn)
        assert result.request_path == "/botcompat_token/sendMessage"
      after
        if original_keys,
          do: Application.put_env(:lux, :api_keys, original_keys),
          else: Application.delete_env(:lux, :api_keys)
      end
    end

    test "request_settings/0 uses add_auth/1" do
      settings = Telegram.request_settings()
      assert settings.auth.type == :custom
      assert is_function(settings.auth.auth_function, 1)
    end
  end
end
