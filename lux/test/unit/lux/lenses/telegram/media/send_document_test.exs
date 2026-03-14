defmodule Lux.Lenses.Telegram.Media.SendDocumentTest do
  @moduledoc """
  Test suite for the SendDocument lens.
  These tests verify the lens's ability to:
  - Send documents to Telegram chats (by URL and file_id)
  - Handle optional caption and formatting parameters
  - Handle Telegram API errors appropriately
  - Handle rate limiting (429 responses)
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Media.SendDocument

  @chat_id 123_456_789
  @message_id 456
  @document_url "https://example.com/report.pdf"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully sends a document by URL" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/sendDocument")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["document"] == @document_url
        assert decoded["caption"] == "Monthly report"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "document" => %{
              "file_id" => "BQACAgIAAxkBAAI",
              "file_unique_id" => "unique_doc",
              "file_name" => "report.pdf",
              "mime_type" => "application/pdf",
              "file_size" => 1_234_567
            },
            "caption" => "Monthly report",
            "date" => 1_234_567_890
          }
        }))
      end)

      assert {:ok, result} = SendDocument.focus(%{
        chat_id: @chat_id,
        document: @document_url,
        caption: "Monthly report"
      }, %{})

      assert result.message_id == @message_id
      assert result.chat_id == @chat_id
      assert result.document.file_name == "report.pdf"
      assert result.document.mime_type == "application/pdf"
      assert result.document.file_size == 1_234_567
      assert result.caption == "Monthly report"
    end

    test "successfully sends a document without caption" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "document" => %{
              "file_id" => "BQACAgIAAxkBAAI",
              "file_unique_id" => "unique_doc",
              "file_name" => "data.csv",
              "mime_type" => "text/csv",
              "file_size" => 5000
            },
            "date" => 1_234_567_890
          }
        }))
      end)

      assert {:ok, result} = SendDocument.focus(%{
        chat_id: @chat_id,
        document: "BQACAgIAAxkBAAI..."
      }, %{})

      assert result.document.file_name == "data.csv"
      assert result.caption == nil
    end

    test "handles Telegram API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 400,
          "description" => "Bad Request: wrong file identifier/HTTP URL specified"
        }))
      end)

      assert {:ok, %{reason: :api_error, error_code: 400}} =
        SendDocument.focus(%{
          chat_id: @chat_id,
          document: "invalid"
        }, %{})
    end

    test "handles rate limiting (429)" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests: retry after 60",
          "parameters" => %{"retry_after" => 60}
        }))
      end)

      assert {:ok, %{reason: :rate_limited, retry_after: 60}} =
        SendDocument.focus(%{
          chat_id: @chat_id,
          document: @document_url
        }, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = SendDocument.view()
      assert lens.schema.required == ["chat_id", "document"]
    end

    test "validates schema properties" do
      lens = SendDocument.view()
      assert Map.has_key?(lens.schema.properties, :chat_id)
      assert Map.has_key?(lens.schema.properties, :document)
      assert Map.has_key?(lens.schema.properties, :caption)
      assert Map.has_key?(lens.schema.properties, :parse_mode)
      assert Map.has_key?(lens.schema.properties, :disable_notification)
      assert Map.has_key?(lens.schema.properties, :protect_content)
      assert Map.has_key?(lens.schema.properties, :thumbnail)
      assert Map.has_key?(lens.schema.properties, :disable_content_type_detection)
    end
  end
end
