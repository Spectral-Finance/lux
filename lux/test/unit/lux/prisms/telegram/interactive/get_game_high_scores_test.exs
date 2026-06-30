defmodule Lux.Prisms.Telegram.Interactive.GetGameHighScoresTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.GetGameHighScores

  @user_id 123_456_789
  @chat_id 987_654_321
  @message_id 42
  @inline_message_id "ABCDEF123456"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully gets high scores using chat_id and message_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/getGameHighScores")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["user_id"] == @user_id
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "position" => 1,
              "user" => %{
                "id" => @user_id,
                "is_bot" => false,
                "first_name" => "John",
                "last_name" => "Doe",
                "username" => "johndoe"
              },
              "score" => 100
            },
            %{
              "position" => 2,
              "user" => %{
                "id" => 111_222_333,
                "is_bot" => false,
                "first_name" => "Jane",
                "username" => "janedoe"
              },
              "score" => 75
            }
          ]
        }))
      end)

      assert {:ok, result} = GetGameHighScores.handler(
        %{
          user_id: @user_id,
          chat_id: @chat_id,
          message_id: @message_id,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert result.user_id == @user_id
      assert result.chat_id == @chat_id
      assert result.message_id == @message_id
      assert is_list(result.high_scores)
      assert length(result.high_scores) == 2

      # Check first high score entry
      first_score = Enum.at(result.high_scores, 0)
      assert first_score.position == 1
      assert first_score.score == 100
      assert first_score.user.id == @user_id
      assert first_score.user.first_name == "John"
      assert first_score.user.last_name == "Doe"
      assert first_score.user.username == "johndoe"

      # Check second high score entry
      second_score = Enum.at(result.high_scores, 1)
      assert second_score.position == 2
      assert second_score.score == 75
      assert second_score.user.id == 111_222_333
      assert second_score.user.first_name == "Jane"
      assert second_score.user.username == "janedoe"
      assert second_score.user.last_name == nil
    end

    test "successfully gets high scores using inline_message_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/getGameHighScores")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["user_id"] == @user_id
        assert decoded_body["inline_message_id"] == @inline_message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "position" => 1,
              "user" => %{
                "id" => @user_id,
                "is_bot" => false,
                "first_name" => "John"
              },
              "score" => 100
            }
          ]
        }))
      end)

      assert {:ok, result} = GetGameHighScores.handler(
        %{
          user_id: @user_id,
          inline_message_id: @inline_message_id,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert result.user_id == @user_id
      assert result.inline_message_id == @inline_message_id
      assert is_list(result.high_scores)
      assert length(result.high_scores) == 1

      # Check high score entry
      score = Enum.at(result.high_scores, 0)
      assert score.position == 1
      assert score.score == 100
      assert score.user.id == @user_id
      assert score.user.first_name == "John"
    end

    test "handles empty high scores list" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/getGameHighScores")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => []
        }))
      end)

      assert {:ok, result} = GetGameHighScores.handler(
        %{
          user_id: @user_id,
          chat_id: @chat_id,
          message_id: @message_id,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert result.user_id == @user_id
      assert result.chat_id == @chat_id
      assert result.message_id == @message_id
      assert is_list(result.high_scores)
      assert Enum.empty?(result.high_scores)
    end

    test "validates required user_id parameter" do
      result = GetGameHighScores.handler(
        %{
          chat_id: @chat_id,
          message_id: @message_id
        },
        @agent_ctx
      )

      assert result == {:error, "Missing or invalid user_id"}
    end

    test "validates message identifier parameters" do
      result = GetGameHighScores.handler(
        %{
          user_id: @user_id
        },
        @agent_ctx
      )

      assert result == {:error, "Missing or invalid message identifier: Either (chat_id and message_id) or inline_message_id must be provided"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/getGameHighScores")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: invalid message identifier"
        }))
      end)

      assert {:error, "Failed to get game high scores: Bad Request: invalid message identifier (HTTP 400)"} =
        GetGameHighScores.handler(
          %{
            user_id: @user_id,
            chat_id: @chat_id,
            message_id: @message_id,
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = GetGameHighScores.view()
      assert prism.input_schema.required == ["user_id"]
      assert Map.has_key?(prism.input_schema.properties, :user_id)
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
      assert Map.has_key?(prism.input_schema.properties, :inline_message_id)
    end

    test "validates output schema" do
      prism = GetGameHighScores.view()
      assert prism.output_schema.required == ["user_id", "high_scores"]
      assert Map.has_key?(prism.output_schema.properties, :user_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :inline_message_id)
      assert Map.has_key?(prism.output_schema.properties, :high_scores)
    end
  end
end
