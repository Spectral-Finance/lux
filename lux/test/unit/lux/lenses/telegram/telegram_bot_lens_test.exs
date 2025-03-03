defmodule Lux.Lenses.TelegramBotLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.TelegramBotLens

  setup do
    Req.Test.verify_on_exit!()

    # Set up test token
    original_config = Application.get_env(:lux, :api_keys)

    on_exit(fn ->
      Application.put_env(:lux, :api_keys, original_config)
    end)

    # Set both telegram_bot and integration_telegram_bot keys
    Application.put_env(:lux, :api_keys, [
      telegram_bot: "test_token",
      integration_telegram_bot: "test_integration_token"
    ])

    :ok
  end

  describe "TelegramBotLens" do
    test "adds bot token to URL" do
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

      assert {:ok, %{
        "result" => %{
          "id" => 123456789,
          "username" => "test_bot"
        }
      }} = TelegramBotLens.focus(%{
        method: "getMe",
        token: "test_integration_token"
      })
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

      assert {:ok, %{
        "ok" => true,
        "result" => %{
          "message_id" => 1,
          "text" => "Hello, world!"
        }
      }} = TelegramBotLens.focus(%{
        method: "sendMessage",
        chat_id: "123456789",
        text: "Hello, world!",
        token: "test_integration_token"
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

      assert {:ok, %{
        "ok" => true,
        "result" => %{
          "message_id" => 1,
          "photo" => [%{"file_id" => "photo1"} | _]
        }
      }} = TelegramBotLens.focus(%{
        method: "sendPhoto",
        chat_id: "123456789",
        photo: "https://example.com/image.jpg",
        caption: "Test photo",
        token: "test_integration_token"
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

      assert {:ok, %{
        "ok" => true,
        "result" => %{
          "message_id" => 1,
          "document" => %{"file_id" => "doc1"}
        }
      }} = TelegramBotLens.focus(%{
        method: "sendDocument",
        chat_id: "123456789",
        document: "https://example.com/file.pdf",
        caption: "Test document",
        token: "test_integration_token"
      })
    end

    test "handles error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "ok" => false,
          "description" => "Bad Request: chat not found"
        })
      end)

      assert {:ok, %{
        "ok" => false,
        "description" => "Bad Request: chat not found"
      }} = TelegramBotLens.focus(%{
        method: "sendMessage",
        chat_id: "invalid",
        text: "Hello, world!",
        token: "test_integration_token"
      })
    end

    test "handles unexpected response format" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"unexpected" => "format"})
      end)

      assert {:ok, %{"unexpected" => "format"}} =
        TelegramBotLens.focus(%{
          method: "getMe",
          token: "test_integration_token"
        })
    end

    test "send_quiz/5" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendPoll")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["question"] == "What is Elixir?"
        assert body["options"] == ["A language", "A framework", "A database"]
        assert body["type"] == "quiz"
        assert body["correct_option_id"] == 0

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "poll" => %{
              "id" => "quiz123",
              "question" => "What is Elixir?",
              "options" => [
                %{"text" => "A language", "voter_count" => 0},
                %{"text" => "A framework", "voter_count" => 0},
                %{"text" => "A database", "voter_count" => 0}
              ],
              "type" => "quiz",
              "correct_option_id" => 0
            }
          }
        })
      end)

      assert {:ok, %{"poll" => %{"id" => "quiz123"}}} =
        TelegramBotLens.send_quiz(
          "123456789",
          "What is Elixir?",
          ["A language", "A framework", "A database"],
          0
        )
    end

    test "stop_poll/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "stopPoll")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "id" => "poll123",
            "question" => "Question",
            "is_closed" => true
          }
        })
      end)

      assert {:ok, %{"id" => "poll123", "is_closed" => true}} =
        TelegramBotLens.stop_poll("123456789", 42)
    end

    test "send_game/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendGame")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["game_short_name"] == "test_game"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "game" => %{
              "title" => "Test Game",
              "description" => "A test game",
              "photo" => [%{"file_id" => "game_photo"}]
            }
          }
        })
      end)

      assert {:ok, %{"game" => %{"title" => "Test Game"}}} =
        TelegramBotLens.send_game("123456789", "test_game")
    end

    test "set_game_score/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "setGameScore")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["user_id"] == 123456789
        assert body["score"] == 100
        assert body["chat_id"] == "987654321"
        assert body["message_id"] == 42

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "game" => %{"title" => "Test Game", "score" => 100}
          }
        })
      end)

      assert {:ok, %{"game" => %{"score" => 100}}} =
        TelegramBotLens.set_game_score(123456789, 100, %{
          chat_id: "987654321",
          message_id: 42
        })
    end

    test "get_game_high_scores/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "getGameHighScores")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["user_id"] == 123456789
        assert body["chat_id"] == "987654321"
        assert body["message_id"] == 42

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => [
            %{
              "position" => 1,
              "user" => %{"id" => 123456789, "first_name" => "Player 1"},
              "score" => 100
            }
          ]
        })
      end)

      assert {:ok, [%{"score" => 100}]} =
        TelegramBotLens.get_game_high_scores(123456789, %{
          chat_id: "987654321",
          message_id: 42
        })
    end

    test "send_live_location/5" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendLocation")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["latitude"] == 37.7749
        assert body["longitude"] == -122.4194
        assert body["live_period"] == 60

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "location" => %{
              "latitude" => 37.7749,
              "longitude" => -122.4194,
              "live_period" => 60
            }
          }
        })
      end)

      assert {:ok, %{"location" => %{"live_period" => 60}}} =
        TelegramBotLens.send_live_location("123456789", 37.7749, -122.4194, 60)
    end

    test "edit_live_location/5" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "editMessageLiveLocation")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42
        assert body["latitude"] == 37.7750
        assert body["longitude"] == -122.4195

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "location" => %{
              "latitude" => 37.7750,
              "longitude" => -122.4195
            }
          }
        })
      end)

      assert {:ok, %{"location" => %{"latitude" => 37.7750}}} =
        TelegramBotLens.edit_live_location("123456789", 42, 37.7750, -122.4195)
    end

    test "stop_live_location/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "stopMessageLiveLocation")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "location" => %{
              "latitude" => 37.7749,
              "longitude" => -122.4194,
              "live_period" => 0
            }
          }
        })
      end)

      assert {:ok, %{"location" => %{"live_period" => 0}}} =
        TelegramBotLens.stop_live_location("123456789", 42)
    end

    test "get_sticker_set/1" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "getStickerSet")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["name"] == "test_set"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "name" => "test_set",
            "title" => "Test Sticker Set",
            "sticker_type" => "regular",
            "stickers" => [
              %{
                "file_id" => "sticker1",
                "width" => 512,
                "height" => 512,
                "is_animated" => false
              }
            ]
          }
        })
      end)

      assert {:ok, %{"name" => "test_set", "stickers" => [%{"file_id" => "sticker1"}]}} =
        TelegramBotLens.get_sticker_set("test_set")
    end

    test "create_article_result/4" do
      input_content = TelegramBotLens.create_text_content("Test message")
      result = TelegramBotLens.create_article_result("1", "Test Title", input_content, %{
        description: "Test description"
      })

      assert result.type == "article"
      assert result.id == "1"
      assert result.title == "Test Title"
      assert result.description == "Test description"
      assert result.input_message_content == input_content
    end

    test "create_photo_result/4" do
      result = TelegramBotLens.create_photo_result(
        "1",
        "https://example.com/photo.jpg",
        "https://example.com/thumb.jpg",
        %{title: "Test Photo"}
      )

      assert result.type == "photo"
      assert result.id == "1"
      assert result.photo_url == "https://example.com/photo.jpg"
      assert result.thumbnail_url == "https://example.com/thumb.jpg"
      assert result.title == "Test Photo"
    end

    test "answer_inline_query/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "answerInlineQuery")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["inline_query_id"] == "query123"
        assert is_list(body["results"])
        assert length(body["results"]) == 1
        assert hd(body["results"])["type"] == "article"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      text_content = TelegramBotLens.create_text_content("Test message")
      result = TelegramBotLens.create_article_result("1", "Test Title", text_content)

      assert {:ok, true} =
        TelegramBotLens.answer_inline_query("query123", [result], %{cache_time: 300})
    end

    test "set_inline_handler/2" do
      handler = fn query ->
        text_content = TelegramBotLens.create_text_content("You searched for: #{query["query"]}")
        [TelegramBotLens.create_article_result("1", "Result", text_content)]
      end

      TelegramBotLens.set_inline_handler(handler, %{cache_time: 300})

      assert {^handler, %{cache_time: 300}} = Process.get(:telegram_inline_handler)
    end

    test "process_inline_query/1 with handler set" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "answerInlineQuery")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["inline_query_id"] == "query123"
        assert is_list(body["results"])
        assert length(body["results"]) == 1
        [result] = body["results"]
        assert result["type"] == "article"
        assert result["input_message_content"]["message_text"] == "You searched for: test"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      handler = fn query ->
        text_content = TelegramBotLens.create_text_content("You searched for: #{query["query"]}")
        [TelegramBotLens.create_article_result("1", "Result", text_content)]
      end

      TelegramBotLens.set_inline_handler(handler, %{cache_time: 300})

      assert {:ok, true} =
        TelegramBotLens.process_inline_query(%{
          "id" => "query123",
          "from" => %{"id" => 123456789},
          "query" => "test"
        })
    end

    test "process_inline_query/1 without handler" do
      Process.delete(:telegram_inline_handler)

      assert {:error, "No inline query handler set"} =
        TelegramBotLens.process_inline_query(%{
          "id" => "query123",
          "query" => "test"
        })
    end

    test "set_webhook/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "setWebhook")

        # Parse the request body JSON
        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["method"] == "setWebhook"
        assert body["url"] == "https://example.com/webhook"
        assert body["max_connections"] == 40

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true,
          "description" => "Webhook was set"
        })
      end)

      assert {:ok, true} = TelegramBotLens.set_webhook(
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

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["voice"] == "https://example.com/voice.ogg"
        assert body["caption"] == "Voice message"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "voice" => %{
              "file_id" => "voice1",
              "duration" => 10
            }
          }
        })
      end)

      assert {:ok, %{
        "chat" => %{"id" => 123456789},
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 1,
        "voice" => %{"duration" => 10, "file_id" => "voice1"}
      }} = TelegramBotLens.send_voice(
        "123456789",
        "https://example.com/voice.ogg",
        %{caption: "Voice message"}
      )
    end

    test "send_animation/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendAnimation")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["animation"] == "https://example.com/animation.gif"
        assert body["caption"] == "Fun animation"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "animation" => %{
              "file_id" => "anim1",
              "width" => 320,
              "height" => 240,
              "duration" => 5
            }
          }
        })
      end)

      assert {:ok, %{
        "animation" => %{
          "duration" => 5,
          "file_id" => "anim1",
          "height" => 240,
          "width" => 320
        },
        "chat" => %{"id" => 123456789},
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 1
      }} = TelegramBotLens.send_animation(
        "123456789",
        "https://example.com/animation.gif",
        %{caption: "Fun animation"}
      )
    end

    test "send_venue/5" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendVenue")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["latitude"] == 37.7749
        assert body["longitude"] == -122.4194
        assert body["title"] == "Telegram HQ"
        assert body["address"] == "123 Main St"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "venue" => %{
              "location" => %{
                "latitude" => 37.7749,
                "longitude" => -122.4194
              },
              "title" => "Telegram HQ",
              "address" => "123 Main St"
            }
          }
        })
      end)

      assert {:ok, %{
        "chat" => %{"id" => 123456789},
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 1,
        "venue" => %{
          "address" => "123 Main St",
          "location" => %{"latitude" => 37.7749, "longitude" => -122.4194},
          "title" => "Telegram HQ"
        }
      }} = TelegramBotLens.send_venue(
        "123456789",
        37.7749,
        -122.4194,
        "Telegram HQ",
        "123 Main St"
      )
    end

    test "send_contact/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendContact")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["phone_number"] == "+1234567890"
        assert body["first_name"] == "John"
        assert body["last_name"] == "Doe"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "contact" => %{
              "phone_number" => "+1234567890",
              "first_name" => "John",
              "last_name" => "Doe"
            }
          }
        })
      end)

      assert {:ok, %{
        "chat" => %{"id" => 123456789},
        "contact" => %{
          "first_name" => "John",
          "last_name" => "Doe",
          "phone_number" => "+1234567890"
        },
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 1
      }} = TelegramBotLens.send_contact(
        "123456789",
        "+1234567890",
        "John",
        %{last_name: "Doe"}
      )
    end

    test "send_dice/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendDice")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["emoji"] == "🎲"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "dice" => %{
              "emoji" => "🎲",
              "value" => 6
            }
          }
        })
      end)

      assert {:ok, %{
        "chat" => %{"id" => 123456789},
        "dice" => %{"emoji" => "🎲", "value" => 6},
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 1
      }} = TelegramBotLens.send_dice("123456789", %{emoji: "🎲"})
    end

    test "edit_message_text/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "editMessageText")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42
        assert body["text"] == "Updated text"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "text" => "Updated text",
            "edit_date" => 1234567890
          }
        })
      end)

      assert {:ok, %{
        "chat" => %{"id" => 123456789},
        "edit_date" => 1234567890,
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 42,
        "text" => "Updated text"
      }} = TelegramBotLens.edit_message_text("123456789", 42, "Updated text")
    end

    test "edit_message_caption/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "editMessageCaption")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42
        assert body["caption"] == "Updated caption"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "caption" => "Updated caption",
            "edit_date" => 1234567890
          }
        })
      end)

      assert {:ok, %{
        "caption" => "Updated caption",
        "chat" => %{"id" => 123456789},
        "edit_date" => 1234567890,
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 42
      }} = TelegramBotLens.edit_message_caption("123456789", 42, "Updated caption")
    end

    test "delete_message/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "deleteMessage")

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

      assert {:ok, %{
        "caption" => "Beautiful sunset",
        "chat" => %{"id" => 123456789, "type" => "private"},
        "date" => 1234567890,
        "from" => %{
          "first_name" => "Test Bot",
          "id" => 987654321,
          "is_bot" => true
        },
        "message_id" => 1,
        "photo" => [
          %{"file_id" => "photo1", "file_size" => 1234, "height" => 100, "width" => 100},
          %{"file_id" => "photo2", "file_size" => 5678, "height" => 600, "width" => 800}
        ]
      }} = TelegramBotLens.send_photo(
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

      assert {:ok, %{
        "caption" => "Important document",
        "chat" => %{"id" => 123456789, "type" => "private"},
        "date" => 1234567890,
        "document" => %{
          "file_id" => "doc1",
          "file_name" => "file.pdf",
          "file_size" => 12345,
          "mime_type" => "application/pdf"
        },
        "from" => %{
          "first_name" => "Test Bot",
          "id" => 987654321,
          "is_bot" => true
        },
        "message_id" => 1
      }} = TelegramBotLens.send_document(
        "123456789",
        "https://example.com/file.pdf",
        %{caption: "Important document"}
      )
    end

    test "send_video/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendVideo")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["video"] == "https://example.com/video.mp4"
        assert body["caption"] == "Test video"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "video" => %{
              "file_id" => "video1",
              "width" => 1280,
              "height" => 720,
              "duration" => 30
            }
          }
        })
      end)

      assert {:ok, %{
        "chat" => %{"id" => 123456789},
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 1,
        "video" => %{
          "duration" => 30,
          "file_id" => "video1",
          "height" => 720,
          "width" => 1280
        }
      }} = TelegramBotLens.send_video(
        "123456789",
        "https://example.com/video.mp4",
        %{caption: "Test video"}
      )
    end

    test "send_audio/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendAudio")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["audio"] == "https://example.com/audio.mp3"
        assert body["caption"] == "Test audio"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "audio" => %{
              "file_id" => "audio1",
              "duration" => 180,
              "title" => "Test Track"
            }
          }
        })
      end)

      assert {:ok, %{
        "audio" => %{
          "duration" => 180,
          "file_id" => "audio1",
          "title" => "Test Track"
        },
        "chat" => %{"id" => 123456789},
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 1
      }} = TelegramBotLens.send_audio(
        "123456789",
        "https://example.com/audio.mp3",
        %{caption: "Test audio"}
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

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["url"] == "https://example.com/webhook"
        assert body["max_connections"] == 40

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true,
          "description" => "Webhook was set"
        })
      end)

      assert {:ok, true} = TelegramBotLens.set_webhook(
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

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["voice"] == "https://example.com/voice.ogg"
        assert body["caption"] == "Voice message"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "voice" => %{
              "file_id" => "voice1",
              "duration" => 10
            }
          }
        })
      end)

      assert {:ok, %{
        "chat" => %{"id" => 123456789},
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 1,
        "voice" => %{"duration" => 10, "file_id" => "voice1"}
      }} = TelegramBotLens.send_voice(
        "123456789",
        "https://example.com/voice.ogg",
        %{caption: "Voice message"}
      )
    end

    test "send_animation/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendAnimation")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["animation"] == "https://example.com/animation.gif"
        assert body["caption"] == "Fun animation"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "animation" => %{
              "file_id" => "anim1",
              "width" => 320,
              "height" => 240,
              "duration" => 5
            }
          }
        })
      end)

      assert {:ok, %{
        "animation" => %{
          "duration" => 5,
          "file_id" => "anim1",
          "height" => 240,
          "width" => 320
        },
        "chat" => %{"id" => 123456789},
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 1
      }} = TelegramBotLens.send_animation(
        "123456789",
        "https://example.com/animation.gif",
        %{caption: "Fun animation"}
      )
    end

    test "send_venue/5" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendVenue")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["latitude"] == 37.7749
        assert body["longitude"] == -122.4194
        assert body["title"] == "Telegram HQ"
        assert body["address"] == "123 Main St"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "venue" => %{
              "location" => %{
                "latitude" => 37.7749,
                "longitude" => -122.4194
              },
              "title" => "Telegram HQ",
              "address" => "123 Main St"
            }
          }
        })
      end)

      assert {:ok, %{
        "chat" => %{"id" => 123456789},
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 1,
        "venue" => %{
          "address" => "123 Main St",
          "location" => %{"latitude" => 37.7749, "longitude" => -122.4194},
          "title" => "Telegram HQ"
        }
      }} = TelegramBotLens.send_venue(
        "123456789",
        37.7749,
        -122.4194,
        "Telegram HQ",
        "123 Main St"
      )
    end

    test "send_contact/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendContact")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["phone_number"] == "+1234567890"
        assert body["first_name"] == "John"
        assert body["last_name"] == "Doe"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "contact" => %{
              "phone_number" => "+1234567890",
              "first_name" => "John",
              "last_name" => "Doe"
            }
          }
        })
      end)

      assert {:ok, %{
        "chat" => %{"id" => 123456789},
        "contact" => %{
          "first_name" => "John",
          "last_name" => "Doe",
          "phone_number" => "+1234567890"
        },
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 1
      }} = TelegramBotLens.send_contact(
        "123456789",
        "+1234567890",
        "John",
        %{last_name: "Doe"}
      )
    end

    test "send_dice/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendDice")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["emoji"] == "🎲"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "dice" => %{
              "emoji" => "🎲",
              "value" => 6
            }
          }
        })
      end)

      assert {:ok, %{
        "chat" => %{"id" => 123456789},
        "dice" => %{"emoji" => "🎲", "value" => 6},
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 1
      }} = TelegramBotLens.send_dice("123456789", %{emoji: "🎲"})
    end

    test "edit_message_text/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "editMessageText")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42
        assert body["text"] == "Updated text"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "text" => "Updated text",
            "edit_date" => 1234567890
          }
        })
      end)

      assert {:ok, %{
        "chat" => %{"id" => 123456789},
        "edit_date" => 1234567890,
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 42,
        "text" => "Updated text"
      }} = TelegramBotLens.edit_message_text("123456789", 42, "Updated text")
    end

    test "edit_message_caption/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "editMessageCaption")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42
        assert body["caption"] == "Updated caption"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "caption" => "Updated caption",
            "edit_date" => 1234567890
          }
        })
      end)

      assert {:ok, %{
        "caption" => "Updated caption",
        "chat" => %{"id" => 123456789},
        "edit_date" => 1234567890,
        "from" => %{"id" => 987654321, "is_bot" => true},
        "message_id" => 42
      }} = TelegramBotLens.edit_message_caption("123456789", 42, "Updated caption")
    end

    test "delete_message/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "deleteMessage")

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
