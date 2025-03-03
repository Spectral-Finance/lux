defmodule Lux.Lenses.TelegramBotLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.TelegramBotLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "TelegramBotLens" do
    test "adds bot token to URL" do
      # Mock the config to return a test token
      original_config = Application.get_env(:lux, :api_keys)

      on_exit(fn ->
        Application.put_env(:lux, :api_keys, original_config)
      end)

      # Set both telegram_bot and integration_telegram_bot keys
      Application.put_env(:lux, :api_keys, [
        telegram_bot: "test_token",
        integration_telegram_bot: "test_integration_token"
      ])

      lens = TelegramBotLens.view()
      authenticated_lens = Lux.Lens.authenticate(lens)

      assert authenticated_lens.url == "https://api.telegram.org/bottest_integration_token/"
    end

    test "focus with getMe method" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "getMe")

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "id" => 123456789,
            "is_bot" => true,
            "first_name" => "Test Bot",
            "username" => "test_bot"
          }
        })
      end)

      assert {:ok, %{"id" => 123456789, "username" => "test_bot"}} =
        TelegramBotLens.focus(%{method: "getMe"})
    end

    test "focus with sendMessage method" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendMessage")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["text"] == "Hello, world!"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "text" => "Hello, world!"
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "text" => "Hello, world!"}} =
        TelegramBotLens.focus(%{
          method: "sendMessage",
          chat_id: "123456789",
          text: "Hello, world!"
        })
    end

    test "focus with sendPhoto method" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendPhoto")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["photo"] == "https://example.com/image.jpg"
        assert body["caption"] == "Test photo"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "photo" => [
              %{"file_id" => "photo1", "file_size" => 1234, "width" => 100, "height" => 100},
              %{"file_id" => "photo2", "file_size" => 5678, "width" => 800, "height" => 600}
            ],
            "caption" => "Test photo"
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "photo" => [%{"file_id" => "photo1"} | _]}} =
        TelegramBotLens.focus(%{
          method: "sendPhoto",
          chat_id: "123456789",
          photo: "https://example.com/image.jpg",
          caption: "Test photo"
        })
    end

    test "focus with sendDocument method" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendDocument")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["document"] == "https://example.com/file.pdf"
        assert body["caption"] == "Test document"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "document" => %{
              "file_id" => "doc1",
              "file_name" => "file.pdf",
              "mime_type" => "application/pdf",
              "file_size" => 12345
            },
            "caption" => "Test document"
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "document" => %{"file_id" => "doc1"}}} =
        TelegramBotLens.focus(%{
          method: "sendDocument",
          chat_id: "123456789",
          document: "https://example.com/file.pdf",
          caption: "Test document"
        })
    end

    test "handles error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "ok" => false,
          "description" => "Bad Request: chat not found"
        })
      end)

      assert {:error, "Bad Request: chat not found"} =
        TelegramBotLens.focus(%{
          method: "sendMessage",
          chat_id: "invalid",
          text: "Hello, world!"
        })
    end

    test "handles unexpected response format" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"unexpected" => "format"})
      end)

      assert {:error, "Unexpected response format: " <> _} =
        TelegramBotLens.focus(%{method: "getMe"})
    end
  end

  describe "helper functions" do
    test "get_me/0" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "getMe")

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "id" => 123456789,
            "is_bot" => true,
            "first_name" => "Test Bot",
            "username" => "test_bot"
          }
        })
      end)

      assert {:ok, %{"id" => 123456789, "username" => "test_bot"}} =
        TelegramBotLens.get_me()
    end

    test "send_message/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendMessage")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["text"] == "Hello, world!"
        assert body["parse_mode"] == "Markdown"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "text" => "Hello, world!"
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "text" => "Hello, world!"}} =
        TelegramBotLens.send_message("123456789", "Hello, world!", %{parse_mode: "Markdown"})
    end

    test "send_photo/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendPhoto")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["photo"] == "https://example.com/image.jpg"
        assert body["caption"] == "Beautiful sunset"
        assert body["parse_mode"] == "HTML"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "photo" => [
              %{"file_id" => "photo1", "file_size" => 1234, "width" => 100, "height" => 100},
              %{"file_id" => "photo2", "file_size" => 5678, "width" => 800, "height" => 600}
            ],
            "caption" => "Beautiful sunset"
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "photo" => [%{"file_id" => "photo1"} | _]}} =
        TelegramBotLens.send_photo(
          "123456789",
          "https://example.com/image.jpg",
          %{caption: "Beautiful sunset", parse_mode: "HTML"}
        )
    end

    test "send_document/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendDocument")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["document"] == "https://example.com/file.pdf"
        assert body["caption"] == "Important document"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "document" => %{
              "file_id" => "doc1",
              "file_name" => "file.pdf",
              "mime_type" => "application/pdf",
              "file_size" => 12345
            },
            "caption" => "Important document"
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "document" => %{"file_id" => "doc1"}}} =
        TelegramBotLens.send_document(
          "123456789",
          "https://example.com/file.pdf",
          %{caption: "Important document"}
        )
    end

    test "send_video/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendVideo")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["video"] == "https://example.com/video.mp4"
        assert body["caption"] == "Check out this video"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "video" => %{
              "file_id" => "video1",
              "file_name" => "video.mp4",
              "mime_type" => "video/mp4",
              "file_size" => 54321,
              "width" => 1280,
              "height" => 720,
              "duration" => 30
            },
            "caption" => "Check out this video"
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "video" => %{"file_id" => "video1"}}} =
        TelegramBotLens.send_video(
          "123456789",
          "https://example.com/video.mp4",
          %{caption: "Check out this video"}
        )
    end

    test "send_audio/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendAudio")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["audio"] == "https://example.com/audio.mp3"
        assert body["caption"] == "New song"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "audio" => %{
              "file_id" => "audio1",
              "file_name" => "audio.mp3",
              "mime_type" => "audio/mpeg",
              "file_size" => 3456,
              "duration" => 180,
              "performer" => "Artist",
              "title" => "Song Title"
            },
            "caption" => "New song"
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "audio" => %{"file_id" => "audio1"}}} =
        TelegramBotLens.send_audio(
          "123456789",
          "https://example.com/audio.mp3",
          %{caption: "New song"}
        )
    end

    test "send_location/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendLocation")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["latitude"] == 37.7749
        assert body["longitude"] == -122.4194

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "location" => %{
              "latitude" => 37.7749,
              "longitude" => -122.4194
            }
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "location" => %{"latitude" => 37.7749}}} =
        TelegramBotLens.send_location("123456789", 37.7749, -122.4194)
    end

    test "get_updates/1" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "getUpdates")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["offset"] == 123456789
        assert body["limit"] == 10

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => [
            %{
              "update_id" => 123456790,
              "message" => %{
                "message_id" => 1,
                "from" => %{"id" => 123456789, "first_name" => "User"},
                "chat" => %{"id" => 123456789, "type" => "private"},
                "date" => 1234567890,
                "text" => "Hello, bot!"
              }
            }
          ]
        })
      end)

      assert {:ok, [%{"update_id" => 123456790, "message" => %{"text" => "Hello, bot!"}}]} =
        TelegramBotLens.get_updates(%{offset: 123456789, limit: 10})
    end

    test "set_webhook/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "setWebhook")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["url"] == "https://example.com/webhook"
        assert body["max_connections"] == 40

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true,
          "description" => "Webhook was set"
        })
      end)

      assert {:ok, true} =
        TelegramBotLens.set_webhook(
          "https://example.com/webhook",
          %{max_connections: 40}
        )
    end

    test "delete_webhook/1" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "deleteWebhook")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["drop_pending_updates"] == true

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true,
          "description" => "Webhook was deleted"
        })
      end)

      assert {:ok, true} =
        TelegramBotLens.delete_webhook(%{drop_pending_updates: true})
    end

    test "get_webhook_info/0" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "getWebhookInfo")

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "url" => "https://example.com/webhook",
            "has_custom_certificate" => false,
            "pending_update_count" => 0,
            "max_connections" => 40,
            "ip_address" => "12.34.56.78"
          }
        })
      end)

      assert {:ok, %{"url" => "https://example.com/webhook", "has_custom_certificate" => false}} =
        TelegramBotLens.get_webhook_info()
    end

    test "send_media_group/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendMediaGroup")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert is_list(body["media"])
        assert length(body["media"]) == 2
        assert Enum.at(body["media"], 0)["type"] == "photo"
        assert Enum.at(body["media"], 1)["type"] == "photo"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => [
            %{
              "message_id" => 1,
              "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
              "chat" => %{"id" => 123456789, "type" => "private"},
              "date" => 1234567890,
              "photo" => [
                %{"file_id" => "photo1", "file_size" => 1234, "width" => 100, "height" => 100}
              ]
            },
            %{
              "message_id" => 2,
              "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
              "chat" => %{"id" => 123456789, "type" => "private"},
              "date" => 1234567890,
              "photo" => [
                %{"file_id" => "photo2", "file_size" => 5678, "width" => 800, "height" => 600}
              ],
              "caption" => "Second image"
            }
          ]
        })
      end)

      media = [
        %{type: "photo", media: "https://example.com/image1.jpg"},
        %{type: "photo", media: "https://example.com/image2.jpg", caption: "Second image"}
      ]

      assert {:ok, [%{"message_id" => 1}, %{"message_id" => 2, "caption" => "Second image"}]} =
        TelegramBotLens.send_media_group("123456789", media)
    end

    test "send_voice/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendVoice")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["voice"] == "https://example.com/voice.ogg"
        assert body["caption"] == "Voice message"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "voice" => %{
              "file_id" => "voice1",
              "file_size" => 12345,
              "mime_type" => "audio/ogg",
              "duration" => 5
            },
            "caption" => "Voice message"
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "voice" => %{"file_id" => "voice1"}}} =
        TelegramBotLens.send_voice(
          "123456789",
          "https://example.com/voice.ogg",
          %{caption: "Voice message"}
        )
    end

    test "send_animation/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendAnimation")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["animation"] == "https://example.com/animation.gif"
        assert body["caption"] == "Funny GIF"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "animation" => %{
              "file_id" => "anim1",
              "file_name" => "animation.gif",
              "mime_type" => "image/gif",
              "file_size" => 54321,
              "width" => 320,
              "height" => 240,
              "duration" => 3
            },
            "caption" => "Funny GIF"
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "animation" => %{"file_id" => "anim1"}}} =
        TelegramBotLens.send_animation(
          "123456789",
          "https://example.com/animation.gif",
          %{caption: "Funny GIF"}
        )
    end

    test "send_poll/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendPoll")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["question"] == "Favorite color?"
        assert body["options"] == ["Red", "Green", "Blue"]
        assert body["is_anonymous"] == false

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "poll" => %{
              "id" => "poll123456789",
              "question" => "Favorite color?",
              "options" => [
                %{"text" => "Red", "voter_count" => 0},
                %{"text" => "Green", "voter_count" => 0},
                %{"text" => "Blue", "voter_count" => 0}
              ],
              "total_voter_count" => 0,
              "is_closed" => false,
              "is_anonymous" => false,
              "type" => "regular",
              "allows_multiple_answers" => false
            }
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "poll" => %{"question" => "Favorite color?"}}} =
        TelegramBotLens.send_poll(
          "123456789",
          "Favorite color?",
          ["Red", "Green", "Blue"],
          %{is_anonymous: false}
        )
    end

    test "send_contact/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendContact")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["phone_number"] == "+1234567890"
        assert body["first_name"] == "John"
        assert body["last_name"] == "Doe"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "contact" => %{
              "phone_number" => "+1234567890",
              "first_name" => "John",
              "last_name" => "Doe"
            }
          }
        })
      end)

      assert {:ok, %{"message_id" => 1, "contact" => %{"first_name" => "John"}}} =
        TelegramBotLens.send_contact(
          "123456789",
          "+1234567890",
          "John",
          %{last_name: "Doe"}
        )
    end

    test "edit_message_text/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "editMessageText")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42
        assert body["text"] == "Updated message text"
        assert body["parse_mode"] == "Markdown"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "from" => %{"id" => 987654321, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123456789, "type" => "private"},
            "date" => 1234567890,
            "edit_date" => 1234567891,
            "text" => "Updated message text"
          }
        })
      end)

      assert {:ok, %{"message_id" => 42, "text" => "Updated message text"}} =
        TelegramBotLens.edit_message_text(
          "123456789",
          42,
          "Updated message text",
          %{parse_mode: "Markdown"}
        )
    end

    test "delete_message/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "deleteMessage")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} = TelegramBotLens.delete_message("123456789", 42)
    end
  end
end
