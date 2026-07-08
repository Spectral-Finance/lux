defmodule Lux.Prisms.Telegram.Interactive.SendPollTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.SendPoll

  @chat_id "123456789"
  @question "What is your favorite color?"
  @options ["Red", "Green", "Blue", "Yellow"]
  @message_id 42
  @agent_ctx %{name: "Agent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "sends a basic poll" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendPoll")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["question"] == @question
        assert decoded_body["options"] == @options

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id},
            "poll" => %{
              "id" => "poll123456",
              "question" => @question,
              "options" => [
                %{"text" => "Red", "voter_count" => 0},
                %{"text" => "Green", "voter_count" => 0},
                %{"text" => "Blue", "voter_count" => 0},
                %{"text" => "Yellow", "voter_count" => 0}
              ],
              "total_voter_count" => 0,
              "is_closed" => false,
              "is_anonymous" => true,
              "type" => "regular",
              "allows_multiple_answers" => false
            }
          }
        }))
      end)

      assert {:ok, response} = SendPoll.handler(%{
        chat_id: @chat_id,
        question: @question,
        options: @options,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.sent == true
      assert response.message_id == @message_id
      assert response.chat_id == @chat_id
      assert response.question == @question
      assert response.poll_id != nil
      assert response.is_anonymous == true
      assert response.type == "regular"
    end

    test "sends a quiz poll" do
      correct_option_id = 2

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendPoll")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["question"] == @question
        assert decoded_body["options"] == @options
        assert decoded_body["type"] == "quiz"
        assert decoded_body["correct_option_id"] == correct_option_id
        assert decoded_body["explanation"] == "Blue is correct!"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id},
            "poll" => %{
              "id" => "poll123456",
              "question" => @question,
              "options" => [
                %{"text" => "Red", "voter_count" => 0},
                %{"text" => "Green", "voter_count" => 0},
                %{"text" => "Blue", "voter_count" => 0},
                %{"text" => "Yellow", "voter_count" => 0}
              ],
              "total_voter_count" => 0,
              "is_closed" => false,
              "is_anonymous" => true,
              "type" => "quiz",
              "allows_multiple_answers" => false
            }
          }
        }))
      end)

      assert {:ok, response} = SendPoll.handler(%{
        chat_id: @chat_id,
        question: @question,
        options: @options,
        type: "quiz",
        correct_option_id: correct_option_id,
        explanation: "Blue is correct!",
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.sent == true
      assert response.message_id == @message_id
      assert response.chat_id == @chat_id
      assert response.question == @question
      assert response.type == "quiz"
    end

    test "sends poll with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendPoll")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["question"] == @question
        assert decoded_body["options"] == @options
        assert decoded_body["is_anonymous"] == false
        assert decoded_body["allows_multiple_answers"] == true
        assert decoded_body["open_period"] == 300
        assert decoded_body["is_closed"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id},
            "poll" => %{
              "id" => "poll123456",
              "question" => @question,
              "options" => [
                %{"text" => "Red", "voter_count" => 0},
                %{"text" => "Green", "voter_count" => 0},
                %{"text" => "Blue", "voter_count" => 0},
                %{"text" => "Yellow", "voter_count" => 0}
              ],
              "total_voter_count" => 0,
              "is_closed" => false,
              "is_anonymous" => false,
              "type" => "regular",
              "allows_multiple_answers" => true,
              "open_period" => 300
            }
          }
        }))
      end)

      assert {:ok, response} = SendPoll.handler(%{
        chat_id: @chat_id,
        question: @question,
        options: @options,
        is_anonymous: false,
        allows_multiple_answers: true,
        open_period: 300,
        is_closed: false,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.sent == true
      assert response.message_id == @message_id
      assert response.chat_id == @chat_id
      assert response.question == @question
      assert response.is_anonymous == false
      assert response.allows_multiple_answers == true
      assert response.open_period == 300
    end

    test "validates required parameters" do
      assert {:error, "Missing or invalid chat_id"} = SendPoll.handler(%{
        question: @question,
        options: @options
      }, @agent_ctx)

      assert {:error, "Missing or invalid question"} = SendPoll.handler(%{
        chat_id: @chat_id,
        options: @options
      }, @agent_ctx)

      assert {:error, "Missing or invalid options"} = SendPoll.handler(%{
        chat_id: @chat_id,
        question: @question
      }, @agent_ctx)

      assert {:error, "Options must contain at least 2 items"} = SendPoll.handler(%{
        chat_id: @chat_id,
        question: @question,
        options: ["Only one option"]
      }, @agent_ctx)
    end

    test "validates quiz type parameters" do
      assert {:error, "Quiz polls must have a correct_option_id specified"} = SendPoll.handler(%{
        chat_id: @chat_id,
        question: @question,
        options: @options,
        type: "quiz"
      }, @agent_ctx)

      assert {:error, "correct_option_id must be a valid index in the options array"} = SendPoll.handler(%{
        chat_id: @chat_id,
        question: @question,
        options: @options,
        type: "quiz",
        correct_option_id: 10  # Invalid index
      }, @agent_ctx)
    end

    test "handles Telegram API error" do
      error_description = "Bad Request: not enough rights to send polls"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendPoll")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => error_description
        }))
      end)

      result = SendPoll.handler(%{
        chat_id: @chat_id,
        question: @question,
        options: @options,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      expected_error = "Failed to send poll: #{error_description} (HTTP 400)"
      assert {:error, ^expected_error} = result
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendPoll.view()
      assert prism.input_schema.required == ["chat_id", "question", "options"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :question)
      assert Map.has_key?(prism.input_schema.properties, :options)
      assert Map.has_key?(prism.input_schema.properties, :is_anonymous)
      assert Map.has_key?(prism.input_schema.properties, :type)
      assert Map.has_key?(prism.input_schema.properties, :allows_multiple_answers)
      assert Map.has_key?(prism.input_schema.properties, :correct_option_id)
      assert Map.has_key?(prism.input_schema.properties, :is_closed)
      assert Map.has_key?(prism.input_schema.properties, :open_period)
      assert Map.has_key?(prism.input_schema.properties, :explanation)
    end

    test "validates output schema" do
      prism = SendPoll.view()
      assert prism.output_schema.required == ["sent", "message_id", "question"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :question)
      assert Map.has_key?(prism.output_schema.properties, :poll_id)
      assert Map.has_key?(prism.output_schema.properties, :options)
      assert Map.has_key?(prism.output_schema.properties, :is_anonymous)
      assert Map.has_key?(prism.output_schema.properties, :type)
      assert Map.has_key?(prism.output_schema.properties, :allows_multiple_answers)
    end
  end
end
