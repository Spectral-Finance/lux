defmodule Lux.Prisms.Telegram.Media.SendDocumentTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Media.SendDocument

  @chat_id 123_456_789
  @document_url "https://example.com/document.pdf"
  @document_file_id "BQACAgQAAxkBAAIBZWCtPW7GcS9llxJh7SZqAAAAH-E5tQACrroxG6gS0FHr9bwF"
  @caption "Important document"
  @message_id 42
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends a document by URL" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendDocument")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["document"] == @document_url
        assert decoded_body["caption"] == @caption

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "document" => %{
              "file_id" => "document_file_id",
              "file_unique_id" => "document_unique_id",
              "file_name" => "document.pdf",
              "mime_type" => "application/pdf",
              "file_size" => 12_345
            },
            "caption" => @caption
          }
        }))
      end)

      assert {:ok,
              %{sent: true, message_id: @message_id, chat_id: @chat_id, document: @document_url, caption: @caption}} =
               SendDocument.handler(
                 %{
                   chat_id: @chat_id,
                   document: @document_url,
                   caption: @caption,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends a document by file_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendDocument")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["document"] == @document_file_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "document" => %{
              "file_id" => @document_file_id,
              "file_unique_id" => "document_unique_id",
              "file_name" => "document.pdf",
              "mime_type" => "application/pdf",
              "file_size" => 12_345
            }
          }
        }))
      end)

      assert {:ok,
              %{sent: true, message_id: @message_id, chat_id: @chat_id, document: @document_file_id}} =
               SendDocument.handler(
                 %{
                   chat_id: @chat_id,
                   document: @document_file_id,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends a document with markdown caption" do
      markdown_caption = "*Bold* and _italic_ caption"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["document"] == @document_url
        assert decoded_body["caption"] == markdown_caption
        assert decoded_body["parse_mode"] == "Markdown"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "document" => %{
              "file_id" => "document_file_id",
              "file_unique_id" => "document_unique_id",
              "file_name" => "document.pdf",
              "mime_type" => "application/pdf",
              "file_size" => 12_345
            },
            "caption" => markdown_caption,
            "caption_entities" => [
              %{"type" => "bold", "offset" => 0, "length" => 4},
              %{"type" => "italic", "offset" => 10, "length" => 6}
            ]
          }
        }))
      end)

      assert {:ok,
              %{sent: true, caption: ^markdown_caption}} =
               SendDocument.handler(
                 %{
                   chat_id: @chat_id,
                   document: @document_url,
                   caption: markdown_caption,
                   parse_mode: "Markdown",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends a document with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["document"] == @document_url
        assert decoded_body["disable_notification"] == true
        assert decoded_body["protect_content"] == true
        assert decoded_body["reply_to_message_id"] == 10
        assert decoded_body["disable_content_type_detection"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id}
          }
        }))
      end)

      assert {:ok, _result} = SendDocument.handler(
        %{
          chat_id: @chat_id,
          document: @document_url,
          disable_notification: true,
          protect_content: true,
          reply_to_message_id: 10,
          disable_content_type_detection: true,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
    end

    test "validates required parameters" do
      # Missing chat_id
      result = SendDocument.handler(%{document: @document_url}, @agent_ctx)
      assert result == {:error, "Missing or invalid chat_id"}

      # Missing document
      result = SendDocument.handler(%{chat_id: @chat_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid document"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: wrong file identifier/HTTP URL specified"
        }))
      end)

      assert {:error, "Failed to send document: Bad Request: wrong file identifier/HTTP URL specified (HTTP 400)"} =
               SendDocument.handler(
                 %{
                   chat_id: @chat_id,
                   document: "invalid_document_url",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendDocument.view()
      assert prism.input_schema.required == ["chat_id", "document"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :document)
      assert Map.has_key?(prism.input_schema.properties, :caption)
      assert Map.has_key?(prism.input_schema.properties, :parse_mode)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
      assert Map.has_key?(prism.input_schema.properties, :protect_content)
      assert Map.has_key?(prism.input_schema.properties, :disable_content_type_detection)
    end

    test "validates output schema" do
      prism = SendDocument.view()
      assert prism.output_schema.required == ["sent", "message_id"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :document)
      assert Map.has_key?(prism.output_schema.properties, :caption)
    end
  end
end
