defmodule Lux.Prisms.Telegram.Interactive.StopPollTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.StopPoll

  @chat_id "123456789"
  @message_id 42
  @poll_id "poll123456"
  @agent_ctx %{name: "Agent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "stops poll successfully" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/stopPoll")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "id" => @poll_id,
            "question" => "What is your favorite color?",
            "options" => [
              %{"text" => "Red", "voter_count" => 3},
              %{"text" => "Green", "voter_count" => 2},
              %{"text" => "Blue", "voter_count" => 5},
              %{"text" => "Yellow", "voter_count" => 1}
            ],
            "total_voter_count" => 11,
            "is_closed" => true,
            "is_anonymous" => true,
            "type" => "regular",
            "allows_multiple_answers" => false
          }
        }))
      end)

      assert {:ok, response} = StopPoll.handler(%{
        chat_id: @chat_id,
        message_id: @message_id,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.stopped == true
      assert response.message_id == @message_id
      assert response.chat_id == @chat_id
      assert response.poll_id == @poll_id
      assert response.total_voter_count == 11
      assert response.is_closed == true
      assert Enum.count(response.options) == 4
      assert Enum.at(response.options, 0)["text"] == "Red"
      assert Enum.at(response.options, 0)["voter_count"] == 3
      assert Enum.at(response.options, 2)["text"] == "Blue"
      assert Enum.at(response.options, 2)["voter_count"] == 5
    end

    test "validates required parameters" do
      assert {:error, "Missing or invalid chat_id"} = StopPoll.handler(%{
        message_id: @message_id
      }, @agent_ctx)

      assert {:error, "Missing or invalid message_id"} = StopPoll.handler(%{
        chat_id: @chat_id
      }, @agent_ctx)
    end

    test "handles Telegram API error" do
      error_description = "Bad Request: poll can't be stopped"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/stopPoll")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => error_description
        }))
      end)

      result = StopPoll.handler(%{
        chat_id: @chat_id,
        message_id: @message_id,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      expected_error = "Failed to stop poll: #{error_description} (HTTP 400)"
      assert {:error, ^expected_error} = result
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = StopPoll.view()
      assert prism.input_schema.required == ["chat_id", "message_id"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
    end

    test "validates output schema" do
      prism = StopPoll.view()
      assert prism.output_schema.required == ["stopped", "poll_id"]
      assert Map.has_key?(prism.output_schema.properties, :stopped)
      assert Map.has_key?(prism.output_schema.properties, :poll_id)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :total_voter_count)
      assert Map.has_key?(prism.output_schema.properties, :options)
      assert Map.has_key?(prism.output_schema.properties, :is_closed)
    end
  end
end
