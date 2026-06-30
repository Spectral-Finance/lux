defmodule Lux.Prisms.Telegram.Interactive.SetGameScoreTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.SetGameScore

  @user_id 123_456_789
  @score 100
  @chat_id 987_654_321
  @message_id 42
  @inline_message_id "ABCDEF123456"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets a game score using chat_id and message_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/setGameScore")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["user_id"] == @user_id
        assert decoded_body["score"] == @score
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 111_222_333, "is_bot" => true, "first_name" => "TestBot"},
            "chat" => %{"id" => @chat_id}
          }
        }))
      end)

      assert {:ok, result} = SetGameScore.handler(
        %{
          user_id: @user_id,
          score: @score,
          chat_id: @chat_id,
          message_id: @message_id,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert result.set == true
      assert result.user_id == @user_id
      assert result.score == @score
      assert result.chat_id == @chat_id
      assert result.message_id == @message_id
    end

    test "successfully sets a game score using inline_message_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/setGameScore")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["user_id"] == @user_id
        assert decoded_body["score"] == @score
        assert decoded_body["inline_message_id"] == @inline_message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, result} = SetGameScore.handler(
        %{
          user_id: @user_id,
          score: @score,
          inline_message_id: @inline_message_id,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert result.set == true
      assert result.user_id == @user_id
      assert result.score == @score
      assert result.inline_message_id == @inline_message_id
    end

    test "successfully sets a game score with force flag" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/setGameScore")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["user_id"] == @user_id
        assert decoded_body["score"] == @score
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["message_id"] == @message_id
        assert decoded_body["force"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 111_222_333, "is_bot" => true, "first_name" => "TestBot"},
            "chat" => %{"id" => @chat_id}
          }
        }))
      end)

      assert {:ok, result} = SetGameScore.handler(
        %{
          user_id: @user_id,
          score: @score,
          chat_id: @chat_id,
          message_id: @message_id,
          force: true,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert result.set == true
      assert result.user_id == @user_id
      assert result.score == @score
      assert result.chat_id == @chat_id
      assert result.message_id == @message_id
      assert result.force == true
    end

    test "validates required user_id parameter" do
      result = SetGameScore.handler(
        %{
          score: @score,
          chat_id: @chat_id,
          message_id: @message_id
        },
        @agent_ctx
      )

      assert result == {:error, "Missing or invalid user_id"}
    end

    test "validates required score parameter" do
      result = SetGameScore.handler(
        %{
          user_id: @user_id,
          chat_id: @chat_id,
          message_id: @message_id
        },
        @agent_ctx
      )

      assert result == {:error, "Missing or invalid score"}
    end

    test "validates message identifier parameters" do
      result = SetGameScore.handler(
        %{
          user_id: @user_id,
          score: @score
        },
        @agent_ctx
      )

      assert result == {:error, "Missing or invalid message identifier: Either (chat_id and message_id) or inline_message_id must be provided"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/setGameScore")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: score can't be decreased"
        }))
      end)

      assert {:error, "Failed to set game score: Bad Request: score can't be decreased (HTTP 400)"} =
        SetGameScore.handler(
          %{
            user_id: @user_id,
            score: @score,
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
      prism = SetGameScore.view()
      assert prism.input_schema.required == ["user_id", "score"]
      assert Map.has_key?(prism.input_schema.properties, :user_id)
      assert Map.has_key?(prism.input_schema.properties, :score)
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
      assert Map.has_key?(prism.input_schema.properties, :inline_message_id)
      assert Map.has_key?(prism.input_schema.properties, :force)
      assert Map.has_key?(prism.input_schema.properties, :disable_edit_message)
    end

    test "validates output schema" do
      prism = SetGameScore.view()
      assert prism.output_schema.required == ["set", "user_id", "score"]
      assert Map.has_key?(prism.output_schema.properties, :set)
      assert Map.has_key?(prism.output_schema.properties, :user_id)
      assert Map.has_key?(prism.output_schema.properties, :score)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :inline_message_id)
      assert Map.has_key?(prism.output_schema.properties, :force)
    end
  end
end
