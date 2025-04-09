defmodule Lux.Prisms.Telegram.Interactive.AnswerCallbackQueryTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.AnswerCallbackQuery

  @callback_query_id "1234567890"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully answers a callback query with required parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["callback_query_id"] == @callback_query_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{answered: true, callback_query_id: @callback_query_id}} =
               AnswerCallbackQuery.handler(
                 %{
                   callback_query_id: @callback_query_id,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully answers a callback query with text notification" do
      text = "You clicked the button!"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["callback_query_id"] == @callback_query_id
        assert decoded_body["text"] == text

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{answered: true, callback_query_id: @callback_query_id}} =
               AnswerCallbackQuery.handler(
                 %{
                   callback_query_id: @callback_query_id,
                   text: text,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully answers a callback query with an alert" do
      text = "Important notification!"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["callback_query_id"] == @callback_query_id
        assert decoded_body["text"] == text
        assert decoded_body["show_alert"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{answered: true, callback_query_id: @callback_query_id}} =
               AnswerCallbackQuery.handler(
                 %{
                   callback_query_id: @callback_query_id,
                   text: text,
                   show_alert: true,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully answers a callback query with a URL" do
      url = "https://example.com/details"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["callback_query_id"] == @callback_query_id
        assert decoded_body["url"] == url

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{answered: true, callback_query_id: @callback_query_id}} =
               AnswerCallbackQuery.handler(
                 %{
                   callback_query_id: @callback_query_id,
                   url: url,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully answers a callback query with a cache time" do
      cache_time = 60

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["callback_query_id"] == @callback_query_id
        assert decoded_body["cache_time"] == cache_time

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{answered: true, callback_query_id: @callback_query_id}} =
               AnswerCallbackQuery.handler(
                 %{
                   callback_query_id: @callback_query_id,
                   cache_time: cache_time,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates required parameters" do
      result = AnswerCallbackQuery.handler(%{}, @agent_ctx)
      assert result == {:error, "Missing or invalid callback_query_id"}

      result = AnswerCallbackQuery.handler(%{callback_query_id: ""}, @agent_ctx)
      assert result == {:error, "Missing or invalid callback_query_id"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: query is too old and response timeout expired or query ID is invalid"
        }))
      end)

      assert {:error, "Failed to answer callback query: Bad Request: query is too old and response timeout expired or query ID is invalid (HTTP 400)"} =
               AnswerCallbackQuery.handler(
                 %{
                   callback_query_id: @callback_query_id,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = AnswerCallbackQuery.view()
      assert prism.input_schema.required == ["callback_query_id"]
      assert Map.has_key?(prism.input_schema.properties, :callback_query_id)
      assert Map.has_key?(prism.input_schema.properties, :text)
      assert Map.has_key?(prism.input_schema.properties, :show_alert)
      assert Map.has_key?(prism.input_schema.properties, :url)
      assert Map.has_key?(prism.input_schema.properties, :cache_time)
    end

    test "validates output schema" do
      prism = AnswerCallbackQuery.view()
      assert prism.output_schema.required == ["answered", "callback_query_id"]
      assert Map.has_key?(prism.output_schema.properties, :answered)
      assert Map.has_key?(prism.output_schema.properties, :callback_query_id)
    end
  end
end
