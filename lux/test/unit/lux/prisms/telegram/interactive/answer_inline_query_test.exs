defmodule Lux.Prisms.Telegram.Interactive.AnswerInlineQueryTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.AnswerInlineQuery

  @inline_query_id "123456789"
  @agent_ctx %{name: "TestAgent"}

  @results [
    %{
      type: "article",
      id: "1",
      title: "Result 1",
      input_message_content: %{
        message_text: "This is result 1"
      }
    },
    %{
      type: "article",
      id: "2",
      title: "Result 2",
      input_message_content: %{
        message_text: "This is result 2"
      }
    }
  ]

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully answers an inline query with basic results" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/answerInlineQuery")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["inline_query_id"] == @inline_query_id

        # The results should be a JSON string in the request
        results = Jason.decode!(decoded_body["results"])
        assert length(results) == 2
        assert Enum.at(results, 0)["type"] == "article"
        assert Enum.at(results, 0)["id"] == "1"
        assert Enum.at(results, 1)["id"] == "2"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, result} =
        AnswerInlineQuery.handler(
          %{
            inline_query_id: @inline_query_id,
            results: @results,
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )

      assert result.answered == true
      assert result.inline_query_id == @inline_query_id
    end

    test "successfully answers an inline query with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/answerInlineQuery")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["inline_query_id"] == @inline_query_id
        results = Jason.decode!(decoded_body["results"])
        assert length(results) == 1
        assert decoded_body["cache_time"] == 300
        assert decoded_body["is_personal"] == true
        assert decoded_body["next_offset"] == "10"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, result} =
        AnswerInlineQuery.handler(
          %{
            inline_query_id: @inline_query_id,
            results: [@results |> Enum.at(0)],
            cache_time: 300,
            is_personal: true,
            next_offset: "10",
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )

      assert result.answered == true
      assert result.inline_query_id == @inline_query_id
    end

    test "validates required parameters" do
      result = AnswerInlineQuery.handler(%{results: @results}, @agent_ctx)
      assert result == {:error, "Missing or invalid inline_query_id"}

      result = AnswerInlineQuery.handler(%{inline_query_id: @inline_query_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid results"}

      result = AnswerInlineQuery.handler(%{inline_query_id: @inline_query_id, results: []}, @agent_ctx)
      assert result == {:error, "Missing or invalid results"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/answerInlineQuery")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: RESULTS_TOO_MUCH"
        }))
      end)

      assert {:error, "Failed to answer inline query: Bad Request: RESULTS_TOO_MUCH (HTTP 400)"} =
        AnswerInlineQuery.handler(
          %{
            inline_query_id: @inline_query_id,
            results: @results,
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = AnswerInlineQuery.view()
      assert prism.input_schema.required == ["inline_query_id", "results"]
      assert Map.has_key?(prism.input_schema.properties, :inline_query_id)
      assert Map.has_key?(prism.input_schema.properties, :results)
      assert Map.has_key?(prism.input_schema.properties, :cache_time)
      assert Map.has_key?(prism.input_schema.properties, :is_personal)
      assert Map.has_key?(prism.input_schema.properties, :next_offset)
      assert Map.has_key?(prism.input_schema.properties, :button)
    end

    test "validates output schema" do
      prism = AnswerInlineQuery.view()
      assert prism.output_schema.required == ["answered", "inline_query_id"]
      assert Map.has_key?(prism.output_schema.properties, :answered)
      assert Map.has_key?(prism.output_schema.properties, :inline_query_id)
    end
  end
end
