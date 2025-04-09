defmodule Lux.Prisms.Telegram.Interactive.SendGameTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.SendGame

  @chat_id 123_456_789
  @game_short_name "tetris"
  @message_id 42
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends a game with required parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendGame")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["game_short_name"] == @game_short_name

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 111_222_333, "is_bot" => true, "first_name" => "TestBot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_609_459_200,
            "game" => %{
              "title" => "Tetris",
              "description" => "Classic Tetris game",
              "text" => "Play now!",
              "game_short_name" => @game_short_name
            }
          }
        }))
      end)

      assert {:ok, result} = SendGame.handler(
        %{
          chat_id: @chat_id,
          game_short_name: @game_short_name,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert result.sent == true
      assert result.message_id == @message_id
      assert result.chat_id == @chat_id
      assert result.game_short_name == @game_short_name
    end

    test "successfully sends a game with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendGame")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["game_short_name"] == @game_short_name
        assert decoded_body["disable_notification"] == true
        assert decoded_body["protect_content"] == true
        assert decoded_body["reply_to_message_id"] == 10
        assert decoded_body["message_thread_id"] == 20
        assert Map.has_key?(decoded_body, "reply_markup")
        assert is_map(decoded_body["reply_markup"])

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 111_222_333, "is_bot" => true, "first_name" => "TestBot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_609_459_200,
            "game" => %{
              "title" => "Tetris",
              "description" => "Classic Tetris game",
              "text" => "Play now!",
              "game_short_name" => @game_short_name
            }
          }
        }))
      end)

      assert {:ok, result} = SendGame.handler(
        %{
          chat_id: @chat_id,
          game_short_name: @game_short_name,
          disable_notification: true,
          protect_content: true,
          reply_to_message_id: 10,
          message_thread_id: 20,
          reply_markup: %{
            inline_keyboard: [
              [%{text: "Play Tetris", callback_game: %{}}]
            ]
          },
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert result.sent == true
      assert result.message_id == @message_id
      assert result.chat_id == @chat_id
      assert result.game_short_name == @game_short_name
    end

    test "validates required chat_id parameter" do
      result = SendGame.handler(
        %{
          game_short_name: @game_short_name
        },
        @agent_ctx
      )

      assert result == {:error, "Missing or invalid chat_id"}
    end

    test "validates required game_short_name parameter" do
      result = SendGame.handler(
        %{
          chat_id: @chat_id
        },
        @agent_ctx
      )

      assert result == {:error, "Missing or invalid game_short_name"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendGame")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: game_short_name not found"
        }))
      end)

      assert {:error, "Failed to send game: Bad Request: game_short_name not found (HTTP 400)"} =
        SendGame.handler(
          %{
            chat_id: @chat_id,
            game_short_name: "non_existent_game",
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendGame.view()
      assert prism.input_schema.required == ["chat_id", "game_short_name"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :game_short_name)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
      assert Map.has_key?(prism.input_schema.properties, :protect_content)
      assert Map.has_key?(prism.input_schema.properties, :reply_to_message_id)
      assert Map.has_key?(prism.input_schema.properties, :message_thread_id)
      assert Map.has_key?(prism.input_schema.properties, :reply_markup)
    end

    test "validates output schema" do
      prism = SendGame.view()
      assert prism.output_schema.required == ["sent", "message_id", "game_short_name"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :game_short_name)
    end
  end
end
