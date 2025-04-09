defmodule Lux.Prisms.Telegram.Media.SendVideoTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Media.SendVideo

  @chat_id 123_456_789
  @video_url "https://example.com/video.mp4"
  @video_file_id "BAACAgQAAxkBAAIBZWCtPW7GcS9llxJh7SZqAAAAH-E5tQACrroxG6gS0FHr9bwF"
  @caption "Check out this video"
  @message_id 42
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends a video by URL" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendVideo")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["video"] == @video_url
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
            "video" => %{
              "file_id" => "video_file_id",
              "file_unique_id" => "video_unique_id",
              "width" => 1280,
              "height" => 720,
              "duration" => 30,
              "mime_type" => "video/mp4",
              "file_size" => 1_234_567
            },
            "caption" => @caption
          }
        }))
      end)

      assert {:ok,
              %{sent: true, message_id: @message_id, chat_id: @chat_id, video: @video_url, caption: @caption}} =
               SendVideo.handler(
                 %{
                   chat_id: @chat_id,
                   video: @video_url,
                   caption: @caption,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends a video by file_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendVideo")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["video"] == @video_file_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "video" => %{
              "file_id" => @video_file_id,
              "file_unique_id" => "video_unique_id",
              "width" => 1280,
              "height" => 720,
              "duration" => 30,
              "mime_type" => "video/mp4",
              "file_size" => 1_234_567
            }
          }
        }))
      end)

      assert {:ok,
              %{sent: true, message_id: @message_id, chat_id: @chat_id, video: @video_file_id}} =
               SendVideo.handler(
                 %{
                   chat_id: @chat_id,
                   video: @video_file_id,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends a video with markdown caption" do
      markdown_caption = "*Bold* and _italic_ caption"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["video"] == @video_url
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
            "video" => %{
              "file_id" => "video_file_id",
              "file_unique_id" => "video_unique_id",
              "width" => 1280,
              "height" => 720,
              "duration" => 30,
              "mime_type" => "video/mp4",
              "file_size" => 1_234_567
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
               SendVideo.handler(
                 %{
                   chat_id: @chat_id,
                   video: @video_url,
                   caption: markdown_caption,
                   parse_mode: "Markdown",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends a video with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["video"] == @video_url
        assert decoded_body["duration"] == 30
        assert decoded_body["width"] == 1280
        assert decoded_body["height"] == 720
        assert decoded_body["supports_streaming"] == true
        assert decoded_body["has_spoiler"] == true
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

      assert {:ok, _result} = SendVideo.handler(
        %{
          chat_id: @chat_id,
          video: @video_url,
          duration: 30,
          width: 1280,
          height: 720,
          supports_streaming: true,
          has_spoiler: true,
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
      result = SendVideo.handler(%{video: @video_url}, @agent_ctx)
      assert result == {:error, "Missing or invalid chat_id"}

      # Missing video
      result = SendVideo.handler(%{chat_id: @chat_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid video"}
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

      assert {:error, "Failed to send video: Bad Request: wrong file identifier/HTTP URL specified (HTTP 400)"} =
               SendVideo.handler(
                 %{
                   chat_id: @chat_id,
                   video: "invalid_video_url",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendVideo.view()
      assert prism.input_schema.required == ["chat_id", "video"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :video)
      assert Map.has_key?(prism.input_schema.properties, :duration)
      assert Map.has_key?(prism.input_schema.properties, :width)
      assert Map.has_key?(prism.input_schema.properties, :height)
      assert Map.has_key?(prism.input_schema.properties, :thumbnail)
      assert Map.has_key?(prism.input_schema.properties, :caption)
      assert Map.has_key?(prism.input_schema.properties, :parse_mode)
      assert Map.has_key?(prism.input_schema.properties, :has_spoiler)
      assert Map.has_key?(prism.input_schema.properties, :supports_streaming)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
      assert Map.has_key?(prism.input_schema.properties, :protect_content)
    end

    test "validates output schema" do
      prism = SendVideo.view()
      assert prism.output_schema.required == ["sent", "message_id"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :video)
      assert Map.has_key?(prism.output_schema.properties, :caption)
    end
  end
end
