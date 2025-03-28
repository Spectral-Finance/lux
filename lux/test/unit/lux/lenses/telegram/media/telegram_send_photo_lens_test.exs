defmodule Lux.Lenses.Telegram.SendPhotoLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Telegram.SendPhoto

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
    test "sends a photo with required parameters" do
      # Mock the HTTP request
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/sendPhoto")
        assert String.contains?(conn.request_path, "TEST_BOT_TOKEN")

        # Verify the body
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == 123_456_789
        assert decoded_body["photo"] == "https://example.com/photo.jpg"

        # Return a mock response
        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 123,
            "from" => %{"id" => 987_654_321, "is_bot" => true},
            "chat" => %{"id" => 123_456_789, "type" => "private"},
            "date" => 1_617_123_456,
            "photo" => [
              %{
                "file_id" => "photo_file_id_1",
                "file_unique_id" => "unique_1",
                "width" => 100,
                "height" => 100,
                "file_size" => 1024
              }
            ]
          }
        })
      end)

      assert {:ok, result} = SendPhoto.focus(%{
        chat_id: 123_456_789,
        photo: "https://example.com/photo.jpg"
      })

      assert result.message_id == 123
      assert result.chat["id"] == 123_456_789
      assert is_list(result.photo)
      assert length(result.photo) == 1
      assert hd(result.photo)["file_id"] == "photo_file_id_1"
    end

    test "sends a photo with optional parameters" do
      # Mock the HTTP request
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/sendPhoto")

        # Verify the body
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == 123_456_789
        assert decoded_body["photo"] == "https://example.com/photo.jpg"
        assert decoded_body["caption"] == "*Bold* caption"
        assert decoded_body["parse_mode"] == "Markdown"
        assert decoded_body["disable_notification"] == true

        # Return a mock response
        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 123,
            "from" => %{"id" => 987_654_321, "is_bot" => true},
            "chat" => %{"id" => 123_456_789, "type" => "private"},
            "date" => 1_617_123_456,
            "photo" => [
              %{
                "file_id" => "photo_file_id_1",
                "file_unique_id" => "unique_1",
                "width" => 100,
                "height" => 100,
                "file_size" => 1024
              }
            ],
            "caption" => "*Bold* caption"
          }
        })
      end)

      assert {:ok, result} = SendPhoto.focus(%{
        chat_id: 123_456_789,
        photo: "https://example.com/photo.jpg",
        caption: "*Bold* caption",
        parse_mode: "Markdown",
        disable_notification: true
      })

      assert result.message_id == 123
      assert result.caption == "*Bold* caption"
      assert is_list(result.photo)
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

      assert {:error, %{"description" => "Bad Request: test error message", "ok" => false}} =
               SendPhoto.focus(%{
                 chat_id: 123_456_789,
                 photo: "https://example.com/photo.jpg"
               })
    end

    test "handles unexpected response format" do
      # Mock the HTTP request with an unexpected response
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "unexpected" => "format"
        })
      end)

      assert {:error, _} = SendPhoto.focus(%{
        chat_id: 123_456_789,
        photo: "https://example.com/photo.jpg"
      })
    end
  end

  describe "add_bot_token/1" do
    test "adds the bot token to the URL" do
      lens = %Lux.Lens{url: "https://api.telegram.org/bot"}
      result = SendPhoto.add_bot_token(lens)
      assert result.url == "https://api.telegram.org/botTEST_BOT_TOKEN/sendPhoto"
    end
  end

  describe "after_focus/1" do
    test "transforms successful response" do
      response = %{
        "ok" => true,
        "result" => %{
          "message_id" => 123,
          "from" => %{"id" => 987_654_321, "is_bot" => true},
          "chat" => %{"id" => 123_456_789, "type" => "private"},
          "date" => 1_617_123_456,
          "photo" => [
            %{
              "file_id" => "photo_file_id_1",
              "file_unique_id" => "unique_1",
              "width" => 100,
              "height" => 100,
              "file_size" => 1024
            }
          ],
          "caption" => "Test caption"
        }
      }

      assert {:ok, result} = SendPhoto.after_focus(response)
      assert result.message_id == 123
      assert result.chat["id"] == 123_456_789
      assert is_list(result.photo)
      assert result.caption == "Test caption"
    end

    test "transforms error response" do
      response = %{"ok" => false, "description" => "Bad Request: test error message"}
      assert {:error, %{"ok" => false, "description" => "Bad Request: test error message"}} = SendPhoto.after_focus(response)
    end

    test "handles unexpected response format" do
      response = %{"unexpected" => "format"}
      assert {:error, _} = SendPhoto.after_focus(response)
    end
  end
end
