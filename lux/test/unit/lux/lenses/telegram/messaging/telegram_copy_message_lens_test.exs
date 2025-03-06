defmodule Lux.Lenses.Telegram.Messaging.TelegramCopyMessageLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Telegram.Messaging.TelegramCopyMessageLens

  setup do
    # Save original environment
    original_env = Application.get_env(:lux, :env)

    # Set test environment
    Application.put_env(:lux, :env, :test)

    # Set up test API keys in the configuration
    Application.put_env(:lux, :api_keys, [
      telegram_bot: "TEST_BOT_TOKEN",
      integration_telegram_bot: "TEST_BOT_TOKEN"
    ])

    on_exit(fn ->
      # Clean up after tests
      Application.delete_env(:lux, :api_keys)

      # Restore original environment or delete if it was nil
      if original_env do
        Application.put_env(:lux, :env, original_env)
      else
        Application.delete_env(:lux, :env)
      end
    end)

    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/1" do
    test "copies a message with required parameters" do
      # Mock the HTTP request
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/copyMessage")
        assert String.contains?(conn.request_path, "TEST_BOT_TOKEN")

        # Verify the body
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == 123456789
        assert decoded_body["from_chat_id"] == 987654321
        assert decoded_body["message_id"] == 42

        # Return a mock response
        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 123
          }
        })
      end)

      assert {:ok, result} = TelegramCopyMessageLens.focus(%{
        chat_id: 123456789,
        from_chat_id: 987654321,
        message_id: 42
      })

      assert result.message_id == 123
    end

    test "copies a message with optional parameters" do
      # Mock the HTTP request
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/copyMessage")

        # Verify the body
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == 123456789
        assert decoded_body["from_chat_id"] == 987654321
        assert decoded_body["message_id"] == 42
        assert decoded_body["caption"] == "New caption"
        assert decoded_body["parse_mode"] == "Markdown"
        assert decoded_body["disable_notification"] == true
        assert decoded_body["protect_content"] == true

        # Return a mock response
        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 123
          }
        })
      end)

      assert {:ok, result} = TelegramCopyMessageLens.focus(%{
        chat_id: 123456789,
        from_chat_id: 987654321,
        message_id: 42,
        caption: "New caption",
        parse_mode: "Markdown",
        disable_notification: true,
        protect_content: true
      })

      assert result.message_id == 123
    end

    test "focus/1 handles error response from API" do
      # Mock the HTTP request with an error response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Set the status code to 400
        conn = Plug.Conn.put_status(conn, 400)
        # Return a mock error response with a less noisy error message
        Req.Test.json(conn, %{
          "ok" => false,
          "description" => "Bad Request: test error message"
        })
      end)

      assert {:error, "Bad Request: test error message"} =
               TelegramCopyMessageLens.focus(%{
                 chat_id: 123_456_789,
                 from_chat_id: 987_654_321,
                 message_id: 42
               })
    end

    test "handles unexpected response format" do
      # Mock the HTTP request with an unexpected response
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "unexpected" => "format"
        })
      end)

      assert {:error, _} = TelegramCopyMessageLens.focus(%{
        chat_id: 123456789,
        from_chat_id: 987654321,
        message_id: 42
      })
    end
  end

  describe "add_bot_token/1" do
    test "adds the bot token to the URL" do
      lens = %Lux.Lens{url: "https://api.telegram.org/bot"}
      result = TelegramCopyMessageLens.add_bot_token(lens)
      assert result.url == "https://api.telegram.org/botTEST_BOT_TOKEN/copyMessage"
    end
  end

  describe "after_focus/1" do
    test "transforms successful response" do
      response = %{
        "ok" => true,
        "result" => %{
          "message_id" => 123
        }
      }

      assert {:ok, result} = TelegramCopyMessageLens.after_focus(response)
      assert result.message_id == 123
    end

    test "transforms error response" do
      response = %{"ok" => false, "description" => "Bad Request: test error message"}
      assert {:error, "Bad Request: test error message"} = TelegramCopyMessageLens.after_focus(response)
    end

    test "handles unexpected response format" do
      response = %{"unexpected" => "format"}
      assert {:error, _} = TelegramCopyMessageLens.after_focus(response)
    end
  end
end
