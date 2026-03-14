defmodule Lux.Lenses.Telegram.Keyboards.AnswerCallbackTest do
  @moduledoc """
  Test suite for the AnswerCallback lens.
  These tests verify the lens's ability to:
  - Answer callback queries from inline keyboards
  - Handle optional text and show_alert parameters
  - Handle Telegram API errors appropriately
  - Handle rate limiting (429 responses)
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Keyboards.AnswerCallback

  @callback_query_id "4382bfdwdsb323b2d9"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully answers a callback query" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/answerCallbackQuery")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["callback_query_id"] == @callback_query_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{answered: true}} =
        AnswerCallback.focus(%{callback_query_id: @callback_query_id}, %{})
    end

    test "successfully answers with text notification" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["callback_query_id"] == @callback_query_id
        assert decoded["text"] == "Option selected!"
        assert decoded["show_alert"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{answered: true}} =
        AnswerCallback.focus(%{
          callback_query_id: @callback_query_id,
          text: "Option selected!",
          show_alert: false
        }, %{})
    end

    test "successfully answers with alert dialog" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["show_alert"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{answered: true}} =
        AnswerCallback.focus(%{
          callback_query_id: @callback_query_id,
          text: "Are you sure?",
          show_alert: true
        }, %{})
    end

    test "handles invalid callback query id" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 400,
          "description" => "Bad Request: query is too old and response timeout expired or query ID is invalid"
        }))
      end)

      assert {:ok, %{reason: :api_error, error_code: 400}} =
        AnswerCallback.focus(%{callback_query_id: "invalid_id"}, %{})
    end

    test "handles rate limiting (429)" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests: retry after 3",
          "parameters" => %{"retry_after" => 3}
        }))
      end)

      assert {:ok, %{reason: :rate_limited, retry_after: 3}} =
        AnswerCallback.focus(%{callback_query_id: @callback_query_id}, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = AnswerCallback.view()
      assert lens.schema.required == ["callback_query_id"]
    end

    test "validates schema properties" do
      lens = AnswerCallback.view()
      assert Map.has_key?(lens.schema.properties, :callback_query_id)
      assert Map.has_key?(lens.schema.properties, :text)
      assert Map.has_key?(lens.schema.properties, :show_alert)
      assert Map.has_key?(lens.schema.properties, :url)
      assert Map.has_key?(lens.schema.properties, :cache_time)
    end
  end
end
