defmodule Lux.Lenses.TelegramInteractiveFeaturesTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.TelegramInteractiveFeatures

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

  describe "TelegramInteractiveFeatures" do
    test "send_poll/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendPoll")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["question"] == "What's your favorite color?"
        assert body["options"] == ["Red", "Green", "Blue"]

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "poll" => %{
              "id" => "poll123",
              "question" => "What's your favorite color?",
              "options" => [
                %{"text" => "Red", "voter_count" => 0},
                %{"text" => "Green", "voter_count" => 0},
                %{"text" => "Blue", "voter_count" => 0}
              ]
            }
          }
        })
      end)

      assert {:ok, %{"poll" => %{"id" => "poll123"}}} =
        TelegramInteractiveFeatures.send_poll(
          "123456789",
          "What's your favorite color?",
          ["Red", "Green", "Blue"]
        )
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
        TelegramInteractiveFeatures.send_quiz(
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
            "question" => "What's your favorite color?",
            "options" => [
              %{"text" => "Red", "voter_count" => 3},
              %{"text" => "Green", "voter_count" => 2},
              %{"text" => "Blue", "voter_count" => 5}
            ],
            "is_closed" => true
          }
        })
      end)

      assert {:ok, %{"id" => "poll123", "is_closed" => true}} =
        TelegramInteractiveFeatures.stop_poll("123456789", 42)
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
        TelegramInteractiveFeatures.send_game("123456789", "test_game")
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
        TelegramInteractiveFeatures.set_game_score(123456789, 100, %{
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
        TelegramInteractiveFeatures.get_game_high_scores(123456789, %{
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

      assert {:ok, %{"location" => %{"latitude" => 37.7749}}} =
        TelegramInteractiveFeatures.send_live_location("123456789", 37.7749, -122.4194, 60)
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
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "location" => %{
              "latitude" => 37.7750,
              "longitude" => -122.4195,
              "live_period" => 60
            }
          }
        })
      end)

      assert {:ok, %{"location" => %{"latitude" => 37.7750}}} =
        TelegramInteractiveFeatures.edit_live_location("123456789", 42, 37.7750, -122.4195)
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
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "location" => %{
              "latitude" => 37.7750,
              "longitude" => -122.4195
            }
          }
        })
      end)

      assert {:ok, %{"location" => %{"latitude" => 37.7750}}} =
        TelegramInteractiveFeatures.stop_live_location("123456789", 42)
    end

    test "send_sticker/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "sendSticker")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["sticker"] == "sticker_file_id"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "from" => %{"id" => 987654321, "is_bot" => true},
            "chat" => %{"id" => 123456789},
            "sticker" => %{
              "file_id" => "sticker_file_id",
              "width" => 512,
              "height" => 512,
              "is_animated" => false,
              "is_video" => false
            }
          }
        })
      end)

      assert {:ok, %{"sticker" => %{"file_id" => "sticker_file_id"}}} =
        TelegramInteractiveFeatures.send_sticker("123456789", "sticker_file_id")
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
            "is_animated" => false,
            "is_video" => false,
            "stickers" => [
              %{
                "file_id" => "sticker1",
                "width" => 512,
                "height" => 512
              },
              %{
                "file_id" => "sticker2",
                "width" => 512,
                "height" => 512
              }
            ]
          }
        })
      end)

      assert {:ok, %{"stickers" => stickers}} =
        TelegramInteractiveFeatures.get_sticker_set("test_set")
      assert length(stickers) == 2
    end

    test "create_article_result/4" do
      result = TelegramInteractiveFeatures.create_article_result(
        "1",
        "Test Result",
        %{message_text: "This is a test"},
        %{description: "Test description"}
      )

      assert result.type == "article"
      assert result.id == "1"
      assert result.title == "Test Result"
      assert result.input_message_content.message_text == "This is a test"
      assert result.description == "Test description"
    end

    test "create_text_content/2" do
      content = TelegramInteractiveFeatures.create_text_content(
        "This is a test",
        %{parse_mode: "Markdown"}
      )

      assert content.message_text == "This is a test"
      assert content.parse_mode == "Markdown"
    end

    test "create_photo_result/4" do
      result = TelegramInteractiveFeatures.create_photo_result(
        "1",
        "https://example.com/photo.jpg",
        "https://example.com/thumb.jpg",
        %{caption: "Test photo"}
      )

      assert result.type == "photo"
      assert result.id == "1"
      assert result.photo_url == "https://example.com/photo.jpg"
      assert result.thumbnail_url == "https://example.com/thumb.jpg"
      assert result.caption == "Test photo"
    end

    test "answer_inline_query/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "answerInlineQuery")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["inline_query_id"] == "query123"
        assert length(body["results"]) == 1
        assert hd(body["results"])["type"] == "article"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      results = [
        TelegramInteractiveFeatures.create_article_result(
          "1",
          "Test Result",
          %{message_text: "This is a test"}
        )
      ]

      assert {:ok, true} =
        TelegramInteractiveFeatures.answer_inline_query("query123", results)
    end
  end

  @tag :unit
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
      TelegramInteractiveFeatures.send_quiz(
        "123456789",
        "What is Elixir?",
        ["A language", "A framework", "A database"],
        0
      )
  end

  @tag :unit
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
          "question" => "What's your favorite color?",
          "options" => [
            %{"text" => "Red", "voter_count" => 3},
            %{"text" => "Green", "voter_count" => 2},
            %{"text" => "Blue", "voter_count" => 5}
          ],
          "is_closed" => true
        }
      })
    end)

    assert {:ok, %{"id" => "poll123", "is_closed" => true}} =
      TelegramInteractiveFeatures.stop_poll("123456789", 42)
  end

  @tag :unit
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
      TelegramInteractiveFeatures.send_game("123456789", "test_game")
  end

  @tag :unit
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
      TelegramInteractiveFeatures.set_game_score(123456789, 100, %{
        chat_id: "987654321",
        message_id: 42
      })
  end

  @tag :unit
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
      TelegramInteractiveFeatures.get_game_high_scores(123456789, %{
        chat_id: "987654321",
        message_id: 42
      })
  end

  @tag :unit
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

    assert {:ok, %{"location" => %{"latitude" => 37.7749}}} =
      TelegramInteractiveFeatures.send_live_location("123456789", 37.7749, -122.4194, 60)
  end

  @tag :unit
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
          "from" => %{"id" => 987654321, "is_bot" => true},
          "chat" => %{"id" => 123456789},
          "location" => %{
            "latitude" => 37.7750,
            "longitude" => -122.4195,
            "live_period" => 60
          }
        }
      })
    end)

    assert {:ok, %{"location" => %{"latitude" => 37.7750}}} =
      TelegramInteractiveFeatures.edit_live_location("123456789", 42, 37.7750, -122.4195)
  end

  @tag :unit
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
          "from" => %{"id" => 987654321, "is_bot" => true},
          "chat" => %{"id" => 123456789},
          "location" => %{
            "latitude" => 37.7750,
            "longitude" => -122.4195
          }
        }
      })
    end)

    assert {:ok, %{"location" => %{"latitude" => 37.7750}}} =
      TelegramInteractiveFeatures.stop_live_location("123456789", 42)
  end

  @tag :unit
  test "send_sticker/3" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "POST"
      assert String.ends_with?(conn.request_path, "sendSticker")

      body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
      assert body["chat_id"] == "123456789"
      assert body["sticker"] == "sticker_file_id"

      Req.Test.json(conn, %{
        "ok" => true,
        "result" => %{
          "message_id" => 1,
          "from" => %{"id" => 987654321, "is_bot" => true},
          "chat" => %{"id" => 123456789},
          "sticker" => %{
            "file_id" => "sticker_file_id",
            "width" => 512,
            "height" => 512,
            "is_animated" => false,
            "is_video" => false
          }
        }
      })
    end)

    assert {:ok, %{"sticker" => %{"file_id" => "sticker_file_id"}}} =
      TelegramInteractiveFeatures.send_sticker("123456789", "sticker_file_id")
  end

  @tag :unit
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
          "is_animated" => false,
          "is_video" => false,
          "stickers" => [
            %{
              "file_id" => "sticker1",
              "width" => 512,
              "height" => 512
            },
            %{
              "file_id" => "sticker2",
              "width" => 512,
              "height" => 512
            }
          ]
        }
      })
    end)

    assert {:ok, %{"stickers" => stickers}} =
      TelegramInteractiveFeatures.get_sticker_set("test_set")
    assert length(stickers) == 2
  end

  @tag :unit
  test "create_article_result/4" do
    input_content = TelegramInteractiveFeatures.create_text_content("Test message")
    result = TelegramInteractiveFeatures.create_article_result("1", "Test Title", input_content, %{
      description: "Test description",
      thumbnail_url: "https://example.com/thumb.jpg"
    })

    assert result.type == "article"
    assert result.id == "1"
    assert result.title == "Test Title"
    assert result.input_message_content == input_content
    assert result.description == "Test description"
    assert result.thumbnail_url == "https://example.com/thumb.jpg"
  end

  @tag :unit
  test "create_photo_result/4" do
    result = TelegramInteractiveFeatures.create_photo_result(
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

  @tag :unit
  test "answer_inline_query/3" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "POST"
      assert String.ends_with?(conn.request_path, "answerInlineQuery")

      body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
      assert body["inline_query_id"] == "query123"
      assert length(body["results"]) == 1
      assert hd(body["results"])["type"] == "article"
      assert body["cache_time"] == 300

      Req.Test.json(conn, %{
        "ok" => true,
        "result" => true
      })
    end)

    text_content = TelegramInteractiveFeatures.create_text_content("Test message")
    result = TelegramInteractiveFeatures.create_article_result("1", "Test Title", text_content)

    assert {:ok, true} =
      TelegramInteractiveFeatures.answer_inline_query("query123", [result], %{cache_time: 300})
  end

  @tag :unit
  test "set_inline_handler/2" do
    handler = fn query ->
      text_content = TelegramInteractiveFeatures.create_text_content("You searched for: #{query["query"]}")
      [TelegramInteractiveFeatures.create_article_result("1", "Result", text_content)]
    end

    TelegramInteractiveFeatures.set_inline_handler(handler, %{cache_time: 300})

    assert Process.get(:telegram_inline_handler) == {handler, %{cache_time: 300}}
  end

  @tag :unit
  test "process_inline_query/1 with handler set" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "POST"
      assert String.ends_with?(conn.request_path, "answerInlineQuery")

      body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
      assert body["inline_query_id"] == "query123"
      assert length(body["results"]) == 1
      assert hd(body["results"])["type"] == "article"
      assert body["cache_time"] == 300

      Req.Test.json(conn, %{
        "ok" => true,
        "result" => true
      })
    end)

    handler = fn query ->
      text_content = TelegramInteractiveFeatures.create_text_content("You searched for: #{query["query"]}")
      [TelegramInteractiveFeatures.create_article_result("1", "Result", text_content)]
    end

    TelegramInteractiveFeatures.set_inline_handler(handler, %{cache_time: 300})

    assert {:ok, true} =
      TelegramInteractiveFeatures.process_inline_query(%{
        "id" => "query123",
        "query" => "test",
        "from" => %{"id" => 123456789, "first_name" => "Test User"}
      })
  end

  @tag :unit
  test "process_inline_query/1 without handler" do
    # Clear any existing handler
    Process.delete(:telegram_inline_handler)

    assert {:error, "No inline query handler set"} =
      TelegramInteractiveFeatures.process_inline_query(%{
        "id" => "query123",
        "query" => "test",
        "from" => %{"id" => 123456789, "first_name" => "Test User"}
      })
  end
end
