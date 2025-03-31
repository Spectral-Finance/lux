defmodule Lux.Prisms.Telegram.Media.SendPhotoTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Media.SendPhoto

  @chat_id 123_456_789
  @photo_url "https://example.com/photo.jpg"
  @photo_file_id "AgACAgQAAxkBAAIBZWCtPW7GcS9llxJh7SZqAAAAH-E5tQACrroxG6gS0FHr9bwF"
  @caption "A beautiful photo"
  @message_id 42
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends a photo by URL" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendPhoto")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["photo"] == @photo_url
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
            "photo" => [
              %{"file_id" => "small_file_id", "file_unique_id" => "small_unique", "width" => 320, "height" => 240, "file_size" => 12_345},
              %{"file_id" => "medium_file_id", "file_unique_id" => "medium_unique", "width" => 800, "height" => 600, "file_size" => 67_890}
            ],
            "caption" => @caption
          }
        }))
      end)

      assert {:ok,
              %{sent: true, message_id: @message_id, chat_id: @chat_id, photo: @photo_url, caption: @caption}} =
               SendPhoto.handler(
                 %{
                   chat_id: @chat_id,
                   photo: @photo_url,
                   caption: @caption,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends a photo by file_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendPhoto")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["photo"] == @photo_file_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "photo" => [
              %{"file_id" => "small_file_id", "file_unique_id" => "small_unique", "width" => 320, "height" => 240, "file_size" => 12_345},
              %{"file_id" => "medium_file_id", "file_unique_id" => "medium_unique", "width" => 800, "height" => 600, "file_size" => 67_890}
            ]
          }
        }))
      end)

      assert {:ok,
              %{sent: true, message_id: @message_id, chat_id: @chat_id, photo: @photo_file_id}} =
               SendPhoto.handler(
                 %{
                   chat_id: @chat_id,
                   photo: @photo_file_id,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends a photo with markdown caption" do
      markdown_caption = "*Bold* and _italic_ caption"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["photo"] == @photo_url
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
            "photo" => [
              %{"file_id" => "small_file_id", "file_unique_id" => "small_unique", "width" => 320, "height" => 240, "file_size" => 12_345},
              %{"file_id" => "medium_file_id", "file_unique_id" => "medium_unique", "width" => 800, "height" => 600, "file_size" => 67_890}
            ],
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
               SendPhoto.handler(
                 %{
                   chat_id: @chat_id,
                   photo: @photo_url,
                   caption: markdown_caption,
                   parse_mode: "Markdown",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends a photo with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["photo"] == @photo_url
        assert decoded_body["disable_notification"] == true
        assert decoded_body["protect_content"] == true
        assert decoded_body["reply_to_message_id"] == 10

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

      assert {:ok, _result} = SendPhoto.handler(
        %{
          chat_id: @chat_id,
          photo: @photo_url,
          disable_notification: true,
          protect_content: true,
          reply_to_message_id: 10,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
    end

    test "validates required parameters" do
      # Missing chat_id
      result = SendPhoto.handler(%{photo: @photo_url}, @agent_ctx)
      assert result == {:error, "Missing or invalid chat_id"}

      # Missing photo
      result = SendPhoto.handler(%{chat_id: @chat_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid photo"}
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

      assert {:error, "Failed to send photo: Bad Request: wrong file identifier/HTTP URL specified (HTTP 400)"} =
               SendPhoto.handler(
                 %{
                   chat_id: @chat_id,
                   photo: "invalid_photo_url",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendPhoto.view()
      assert prism.input_schema.required == ["chat_id", "photo"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :photo)
      assert Map.has_key?(prism.input_schema.properties, :caption)
      assert Map.has_key?(prism.input_schema.properties, :parse_mode)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
      assert Map.has_key?(prism.input_schema.properties, :protect_content)
    end

    test "validates output schema" do
      prism = SendPhoto.view()
      assert prism.output_schema.required == ["sent", "message_id"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :photo)
      assert Map.has_key?(prism.output_schema.properties, :caption)
    end
  end
end
