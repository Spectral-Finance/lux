defmodule Lux.Prisms.Telegram.Media.SendVideoNoteTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Media.SendVideoNote

  @chat_id 123_456_789
  @video_note_url "https://example.com/video_note.mp4"
  @video_note_file_id "video_note123"
  @message_id 42
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends a video note by URL" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendVideoNote")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["video_note"] == @video_note_url

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "video_note" => %{
              "file_id" => @video_note_url,
              "file_unique_id" => "unique123",
              "length" => 360,
              "duration" => 30,
              "file_size" => 123_456
            }
          }
        }))
      end)

      assert {:ok,
              %{sent: true, message_id: @message_id, chat_id: @chat_id, video_note: @video_note_url}} =
               SendVideoNote.handler(
                 %{
                   chat_id: @chat_id,
                   video_note: @video_note_url,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends a video note by file_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendVideoNote")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["video_note"] == @video_note_file_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "video_note" => %{
              "file_id" => @video_note_file_id,
              "file_unique_id" => "unique123",
              "length" => 360,
              "duration" => 30,
              "file_size" => 123_456
            }
          }
        }))
      end)

      assert {:ok,
              %{sent: true, message_id: @message_id, chat_id: @chat_id, video_note: @video_note_file_id}} =
               SendVideoNote.handler(
                 %{
                   chat_id: @chat_id,
                   video_note: @video_note_file_id,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends a video note with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendVideoNote")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["video_note"] == @video_note_url
        assert decoded_body["duration"] == 30
        assert decoded_body["length"] == 360
        assert decoded_body["disable_notification"] == true
        assert decoded_body["protect_content"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "video_note" => %{
              "file_id" => @video_note_url,
              "file_unique_id" => "unique123",
              "length" => 360,
              "duration" => 30,
              "file_size" => 123_456
            }
          }
        }))
      end)

      assert {:ok,
              %{sent: true, message_id: @message_id, chat_id: @chat_id, video_note: @video_note_url}} =
               SendVideoNote.handler(
                 %{
                   chat_id: @chat_id,
                   video_note: @video_note_url,
                   duration: 30,
                   length: 360,
                   disable_notification: true,
                   protect_content: true,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates required parameters" do
      result = SendVideoNote.handler(%{video_note: @video_note_url}, @agent_ctx)
      assert result == {:error, "Missing or invalid chat_id"}

      result = SendVideoNote.handler(%{chat_id: @chat_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid video_note"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendVideoNote")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: wrong file identifier/HTTP URL specified"
        }))
      end)

      assert {:error, "Failed to send video note: Bad Request: wrong file identifier/HTTP URL specified (HTTP 400)"} =
               SendVideoNote.handler(
                 %{
                   chat_id: @chat_id,
                   video_note: "invalid_video_note_url",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendVideoNote.view()
      assert prism.input_schema.required == ["chat_id", "video_note"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :video_note)
      assert Map.has_key?(prism.input_schema.properties, :duration)
      assert Map.has_key?(prism.input_schema.properties, :length)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
      assert Map.has_key?(prism.input_schema.properties, :protect_content)
    end

    test "validates output schema" do
      prism = SendVideoNote.view()
      assert prism.output_schema.required == ["sent", "message_id"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :video_note)
    end
  end
end
