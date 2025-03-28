defmodule Lux.Lenses.Telegram.ForwardMessageLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Telegram.ForwardMessage

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
    test "forwards a message with required parameters" do
      # Mock the HTTP request
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/forwardMessage")
        assert String.contains?(conn.request_path, "TEST_BOT_TOKEN")

        # Verify the body
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == 123_456_789
        assert decoded_body["from_chat_id"] == 987_654_321
        assert decoded_body["message_id"] == 42

        # Return a mock response
        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 123,
            "from" => %{"id" => 111_222_333, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123_456_789, "type" => "private"},
            "date" => 1_617_123_456,
            "forward_from" => %{"id" => 444_555_666, "first_name" => "Original Sender"},
            "forward_from_chat" => %{"id" => 987_654_321, "type" => "private"},
            "forward_date" => 1_617_123_000,
            "text" => "Original message text"
          }
        })
      end)

      assert {:ok, result} = ForwardMessage.focus(%{
        chat_id: 123_456_789,
        from_chat_id: 987_654_321,
        message_id: 42
      })

      assert result.message_id == 123
      assert result.chat["id"] == 123_456_789
      assert result.forward_from["id"] == 444_555_666
      assert result.forward_from_chat["id"] == 987_654_321
      assert result.text == "Original message text"
    end

    test "forwards a message with optional parameters" do
      # Mock the HTTP request
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/forwardMessage")

        # Verify the body
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == 123_456_789
        assert decoded_body["from_chat_id"] == 987_654_321
        assert decoded_body["message_id"] == 42
        assert decoded_body["disable_notification"] == true
        assert decoded_body["protect_content"] == true

        # Return a mock response
        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 123,
            "from" => %{"id" => 111_222_333, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123_456_789, "type" => "private"},
            "date" => 1_617_123_456,
            "forward_from" => %{"id" => 444_555_666, "first_name" => "Original Sender"},
            "forward_from_chat" => %{"id" => 987_654_321, "type" => "private"},
            "forward_date" => 1_617_123_000,
            "text" => "Original message text"
          }
        })
      end)

      assert {:ok, result} = ForwardMessage.focus(%{
        chat_id: 123_456_789,
        from_chat_id: 987_654_321,
        message_id: 42,
        disable_notification: true,
        protect_content: true
      })

      assert result.message_id == 123
      assert result.forward_from["id"] == 444_555_666
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

      assert {:error, %{"ok" => false, "description" => "Bad Request: test error message"}} =
               ForwardMessage.focus(%{
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

      assert {:error, _} = ForwardMessage.focus(%{
        chat_id: 123_456_789,
        from_chat_id: 987_654_321,
        message_id: 42
      })
    end
  end

  describe "add_bot_token/1" do
    test "adds the bot token to the URL" do
      lens = %Lux.Lens{url: "https://api.telegram.org/bot"}
      result = ForwardMessage.add_bot_token(lens)
      assert result.url == "https://api.telegram.org/botTEST_BOT_TOKEN/forwardMessage"
    end
  end

  describe "after_focus/1" do
    test "transforms successful response" do
      response = %{
        "ok" => true,
        "result" => %{
          "message_id" => 123,
          "from" => %{"id" => 111_222_333, "is_bot" => true, "first_name" => "Test Bot"},
          "chat" => %{"id" => 123_456_789, "type" => "private"},
          "date" => 1_617_123_456,
          "forward_from" => %{"id" => 444_555_666, "first_name" => "Original Sender"},
          "forward_from_chat" => %{"id" => 987_654_321, "type" => "private"},
          "forward_date" => 1_617_123_000,
          "text" => "Original message text"
        }
      }

      assert {:ok, result} = ForwardMessage.after_focus(response)
      assert result.message_id == 123
      assert result.forward_from["id"] == 444_555_666
      assert result.forward_from_chat["id"] == 987_654_321
      assert result.text == "Original message text"
    end

    test "transforms error response" do
      response = %{"ok" => false, "description" => "Bad Request: test error message"}
      assert {:error, %{"ok" => false, "description" => "Bad Request: test error message"}} = ForwardMessage.after_focus(response)
    end

    test "handles unexpected response format" do
      response = %{"unexpected" => "format"}
      assert {:error, _} = ForwardMessage.after_focus(response)
    end
  end
end
