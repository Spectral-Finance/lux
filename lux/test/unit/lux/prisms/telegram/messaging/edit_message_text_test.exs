defmodule Lux.Prisms.Telegram.Messages.EditMessageTextTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.EditMessageText

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully edits a message text with chat_id and message_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/editMessageText")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["chat_id"] == 123_456_789
        assert params["message_id"] == 42
        assert params["text"] == "Updated message text"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "from" => %{"id" => 111_222_333, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123_456_789, "type" => "private"},
            "date" => 1_609_459_200,
            "text" => "Updated message text"
          }
        }))
      end)

      params = %{
        chat_id: 123_456_789,
        message_id: 42,
        text: "Updated message text",
        plug: {Req.Test, __MODULE__}
      }

      assert {:ok, result} = EditMessageText.handler(params, %{name: "Test Agent"})
      assert result.edited == true
      assert result.message_id == 42
      assert result.chat_id == 123_456_789
      assert result.text == "Updated message text"
    end

    test "successfully edits an inline message text" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/editMessageText")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["inline_message_id"] == "123456789abcdef"
        assert params["text"] == "Updated inline message text"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      params = %{
        inline_message_id: "123456789abcdef",
        text: "Updated inline message text",
        plug: {Req.Test, __MODULE__}
      }

      assert {:ok, result} = EditMessageText.handler(params, %{name: "Test Agent"})
      assert result.edited == true
    end

    test "successfully edits a message text with parse_mode" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/editMessageText")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["chat_id"] == 123_456_789
        assert params["message_id"] == 42
        assert params["text"] == "*Bold* and _italic_ text"
        assert params["parse_mode"] == "Markdown"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "from" => %{"id" => 111_222_333, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => 123_456_789, "type" => "private"},
            "date" => 1_609_459_200,
            "text" => "*Bold* and _italic_ text",
            "entities" => [
              %{"type" => "bold", "offset" => 0, "length" => 6},
              %{"type" => "italic", "offset" => 11, "length" => 6}
            ]
          }
        }))
      end)

      params = %{
        chat_id: 123_456_789,
        message_id: 42,
        text: "*Bold* and _italic_ text",
        parse_mode: "Markdown",
        plug: {Req.Test, __MODULE__}
      }

      assert {:ok, result} = EditMessageText.handler(params, %{name: "Test Agent"})
      assert result.edited == true
      assert result.message_id == 42
      assert result.chat_id == 123_456_789
      assert result.text == "*Bold* and _italic_ text"
    end

    test "successfully edits a message with disabled web page preview" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert String.ends_with?(conn.request_path, "/editMessageText")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["disable_web_page_preview"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "chat" => %{"id" => 123_456_789},
            "text" => "https://example.com"
          }
        }))
      end)

      params = %{
        chat_id: 123_456_789,
        message_id: 42,
        text: "https://example.com",
        disable_web_page_preview: true,
        plug: {Req.Test, __MODULE__}
      }

      assert {:ok, _result} = EditMessageText.handler(params, %{name: "Test Agent"})
    end

    test "validates required parameters for chat message" do
      # Missing both chat_id/message_id and inline_message_id
      params = %{
        text: "Updated message text"
      }

      assert {:error, message} = EditMessageText.handler(params, %{name: "Test Agent"})
      assert message =~ "Missing or invalid message identifier"

      # Missing text for chat message
      params = %{
        chat_id: 123_456_789,
        message_id: 42
      }

      assert {:error, message} = EditMessageText.handler(params, %{name: "Test Agent"})
      assert message =~ "Missing or invalid text"

      # Missing text for inline message
      params = %{
        inline_message_id: "123456789abcdef"
      }

      assert {:error, message} = EditMessageText.handler(params, %{name: "Test Agent"})
      assert message =~ "Missing or invalid text"
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: message to edit not found"
        }))
      end)

      params = %{
        chat_id: 123_456_789,
        message_id: 999,
        text: "This message doesn't exist",
        plug: {Req.Test, __MODULE__}
      }

      assert {:error, message} = EditMessageText.handler(params, %{name: "Test Agent"})
      assert message =~ "Failed to edit message text: Bad Request: message to edit not found"
    end
  end

  describe "schema validation" do
    test "input schema requires text parameter" do
      prism = EditMessageText.view()
      assert prism.input_schema.required == ["text"]
    end

    test "output schema includes edited status" do
      prism = EditMessageText.view()
      assert prism.output_schema.required == ["edited"]
      assert prism.output_schema.properties.edited.type == :boolean
    end
  end
end
