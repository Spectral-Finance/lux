defmodule Lux.Integrations.Telegram.ClientTest do
  use UnitAPICase, async: true

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

    test "handles authentication error" do
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

    test "handles API error with description" do
      api_key = @mock_api_key

      with_mock Lux.Config, [:passthrough], [telegram_bot_token: fn -> api_key end] do
        Req.Test.expect(TelegramClientMock, fn conn ->
          assert conn.method == "POST"
          assert conn.request_path == "/bot#{api_key}/sendMessage"

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
            json: %{
              chat_id: 123_456_789,
              text: "Hello, world!"
            }
          })
      end
    end

    test "handles unexpected response format" do
      api_key = @mock_api_key

      with_mock Lux.Config, [:passthrough], [telegram_bot_token: fn -> api_key end] do
        Req.Test.expect(TelegramClientMock, fn conn ->
          assert conn.method == "GET"
          assert conn.request_path == "/bot#{api_key}/getMe"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{
            "unexpected" => "format"
          }))
        end)

        {:error, body} =
          Client.request(:get, "/getMe")

        assert body == %{"unexpected" => "format"}
      end
    end
  end
end
