defmodule Lux.Lenses.Telegram.Media.SendPhotoTest do
  @moduledoc """
  Test suite for the SendPhoto lens.
  These tests verify the lens's ability to:
  - Send photos to Telegram chats (by URL and file_id)
  - Handle optional caption and formatting parameters
  - Handle Telegram API errors appropriately
  - Handle rate limiting (429 responses)
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Media.SendPhoto

  @chat_id 123_456_789
  @message_id 456
  @photo_url "https://example.com/photo.jpg"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully sends a photo by URL" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/sendPhoto")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["photo"] == @photo_url
        assert decoded["caption"] == "A beautiful photo"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "photo" => [
              %{
                "file_id" => "AgACAgIAAx_small",
                "file_unique_id" => "unique_small",
                "width" => 320,
                "height" => 240,
                "file_size" => 12345
              },
              %{
                "file_id" => "AgACAgIAAx_large",
                "file_unique_id" => "unique_large",
                "width" => 800,
                "height" => 600,
                "file_size" => 54321
              }
            ],
            "caption" => "A beautiful photo",
            "date" => 1_234_567_890
          }
        }))
      end)

      assert {:ok, result} = SendPhoto.focus(%{
        chat_id: @chat_id,
        photo: @photo_url,
        caption: "A beautiful photo"
      }, %{})

      assert result.message_id == @message_id
      assert result.chat_id == @chat_id
      assert result.caption == "A beautiful photo"
      assert length(result.photo) == 2

      [small, large] = result.photo
      assert small.width == 320
      assert large.width == 800
      assert large.file_id == "AgACAgIAAx_large"
    end

    test "successfully sends a photo without caption" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "photo" => [
              %{
                "file_id" => "AgACAgIAAx",
                "file_unique_id" => "unique",
                "width" => 640,
                "height" => 480,
                "file_size" => 30000
              }
            ],
            "date" => 1_234_567_890
          }
        }))
      end)

      assert {:ok, result} = SendPhoto.focus(%{
        chat_id: @chat_id,
        photo: "AgACAgIAAxkBAAI..."
      }, %{})

      assert result.message_id == @message_id
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
        SendPhoto.focus(%{
          chat_id: @chat_id,
          photo: "invalid_url"
        }, %{})
    end

    test "handles rate limiting (429)" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests: retry after 45",
          "parameters" => %{"retry_after" => 45}
        }))
      end)

      assert {:ok, %{reason: :rate_limited, retry_after: 45}} =
        SendPhoto.focus(%{
          chat_id: @chat_id,
          photo: @photo_url
        }, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = SendPhoto.view()
      assert lens.schema.required == ["chat_id", "photo"]
    end

    test "validates schema properties" do
      lens = SendPhoto.view()
      assert Map.has_key?(lens.schema.properties, :chat_id)
      assert Map.has_key?(lens.schema.properties, :photo)
      assert Map.has_key?(lens.schema.properties, :caption)
      assert Map.has_key?(lens.schema.properties, :parse_mode)
      assert Map.has_key?(lens.schema.properties, :disable_notification)
      assert Map.has_key?(lens.schema.properties, :protect_content)
      assert Map.has_key?(lens.schema.properties, :has_spoiler)
    end
  end
end
