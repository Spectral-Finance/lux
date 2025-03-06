defmodule Lux.Lenses.Telegram.Messaging.TelegramEditMessageCaptionLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Telegram.Messaging.TelegramEditMessageCaptionLens

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
    test "edits a message caption with required parameters" do
      # Mock the HTTP request
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/editMessageCaption")
        assert String.contains?(conn.request_path, "TEST_BOT_TOKEN")

        # Verify the body
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == 123456789
        assert decoded_body["message_id"] == 42
        assert decoded_body["caption"] == "Updated caption"

        # Return a mock response
        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "caption" => "Updated caption",
            "chat" => %{"id" => 123456789, "type" => "private"},
            "from" => %{"id" => 987654321, "is_bot" => true},
            "date" => 1617123456,
            "edit_date" => 1617123457
          }
        })
      end)

      assert {:ok, result} = TelegramEditMessageCaptionLens.focus(%{
        chat_id: 123456789,
        message_id: 42,
        caption: "Updated caption"
      })

      assert result.message_id == 42
      assert result.caption == "Updated caption"
      assert result.chat["id"] == 123456789
      assert result.edit_date == 1617123457
    end

    test "edits a message with optional parameters" do
      # Mock the HTTP request
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/editMessageCaption")

        # Verify the body
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == 123456789
        assert decoded_body["message_id"] == 42
        assert decoded_body["caption"] == "*Bold* caption"
        assert decoded_body["parse_mode"] == "Markdown"

        # Return a mock response
        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "caption" => "*Bold* caption",
            "chat" => %{"id" => 123456789, "type" => "private"},
            "from" => %{"id" => 987654321, "is_bot" => true},
            "date" => 1617123456,
            "edit_date" => 1617123457
          }
        })
      end)

      assert {:ok, result} = TelegramEditMessageCaptionLens.focus(%{
        chat_id: 123456789,
        message_id: 42,
        caption: "*Bold* caption",
        parse_mode: "Markdown"
      })

      assert result.message_id == 42
      assert result.caption == "*Bold* caption"
    end

    test "edits an inline message" do
      # Mock the HTTP request
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/editMessageCaption")

        # Verify the body
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["inline_message_id"] == "123456789"
        assert decoded_body["caption"] == "Updated inline message caption"

        # Return a mock response
        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, _result} = TelegramEditMessageCaptionLens.focus(%{
        inline_message_id: "123456789",
        caption: "Updated inline message caption"
      })
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
               TelegramEditMessageCaptionLens.focus(%{
                 chat_id: 123_456_789,
                 message_id: 42,
                 caption: "Updated caption"
               })
    end

    test "handles unexpected response format" do
      # Mock the HTTP request with an unexpected response
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "unexpected" => "format"
        })
      end)

      assert {:error, _} = TelegramEditMessageCaptionLens.focus(%{
        chat_id: 123456789,
        message_id: 42,
        caption: "Updated caption"
      })
    end
  end

  describe "add_bot_token/1" do
    test "adds the bot token to the URL" do
      lens = %Lux.Lens{url: "https://api.telegram.org/bot"}
      result = TelegramEditMessageCaptionLens.add_bot_token(lens)
      assert result.url == "https://api.telegram.org/botTEST_BOT_TOKEN/editMessageCaption"
    end
  end

  describe "after_focus/1" do
    test "transforms successful response" do
      response = %{
        "ok" => true,
        "result" => %{
          "message_id" => 42,
          "caption" => "Updated caption",
          "chat" => %{"id" => 123456789, "type" => "private"},
          "from" => %{"id" => 987654321, "is_bot" => true},
          "date" => 1617123456,
          "edit_date" => 1617123457
        }
      }

      assert {:ok, result} = TelegramEditMessageCaptionLens.after_focus(response)
      assert result.message_id == 42
      assert result.caption == "Updated caption"
      assert result.chat["id"] == 123456789
      assert result.edit_date == 1617123457
    end

    test "transforms error response" do
      response = %{"ok" => false, "description" => "Bad Request: test error message"}
      assert {:error, "Bad Request: test error message"} = TelegramEditMessageCaptionLens.after_focus(response)
    end

    test "handles unexpected response format" do
      response = %{"unexpected" => "format"}
      assert {:error, _} = TelegramEditMessageCaptionLens.after_focus(response)
    end
  end
end
