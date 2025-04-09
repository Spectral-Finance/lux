defmodule Lux.Prisms.Telegram.Media.SendAudioTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Media.SendAudio

  @chat_id 123_456_789
  @audio_url "https://example.com/audio.mp3"
  @audio_file_id "AgACAgQAAxkBAAIBZWCtPW7GcS9llxJh7SZqAAAAH-E5tQACrroxG6gS0FHr9bwF"
  @message_id 42
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends audio by URL" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendAudio")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["audio"] == @audio_url

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id},
            "audio" => %{"file_id" => "abc123"}
          }
        }))
      end)

      assert {:ok,
              %{
                sent: true,
                message_id: @message_id,
                chat_id: @chat_id,
                audio: @audio_url
              }} =
               SendAudio.handler(
                 %{
                   chat_id: @chat_id,
                   audio: @audio_url,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends audio by file_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendAudio")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["audio"] == @audio_file_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id},
            "audio" => %{"file_id" => @audio_file_id}
          }
        }))
      end)

      assert {:ok,
              %{
                sent: true,
                message_id: @message_id,
                chat_id: @chat_id,
                audio: @audio_file_id
              }} =
               SendAudio.handler(
                 %{
                   chat_id: @chat_id,
                   audio: @audio_file_id,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends audio with markdown caption" do
      caption = "*Bold* and _italic_ caption"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendAudio")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["audio"] == @audio_url
        assert decoded_body["caption"] == caption
        assert decoded_body["parse_mode"] == "Markdown"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id},
            "audio" => %{"file_id" => "abc123"},
            "caption" => caption
          }
        }))
      end)

      assert {:ok,
              %{
                sent: true,
                message_id: @message_id,
                chat_id: @chat_id,
                audio: @audio_url,
                caption: ^caption
              }} =
               SendAudio.handler(
                 %{
                   chat_id: @chat_id,
                   audio: @audio_url,
                   caption: caption,
                   parse_mode: "Markdown",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends audio with optional parameters" do
      duration = 180
      performer = "Artist Name"
      title = "Song Title"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendAudio")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["audio"] == @audio_url
        assert decoded_body["duration"] == duration
        assert decoded_body["performer"] == performer
        assert decoded_body["title"] == title

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id},
            "audio" => %{
              "file_id" => "abc123",
              "duration" => duration,
              "performer" => performer,
              "title" => title
            }
          }
        }))
      end)

      assert {:ok,
              %{
                sent: true,
                message_id: @message_id,
                chat_id: @chat_id,
                audio: @audio_url
              }} =
               SendAudio.handler(
                 %{
                   chat_id: @chat_id,
                   audio: @audio_url,
                   duration: duration,
                   performer: performer,
                   title: title,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates required parameters" do
      assert {:error, "Missing or invalid chat_id"} =
               SendAudio.handler(
                 %{
                   audio: @audio_url
                 },
                 @agent_ctx
               )

      assert {:error, "Missing or invalid audio"} =
               SendAudio.handler(
                 %{
                   chat_id: @chat_id
                 },
                 @agent_ctx
               )
    end

    test "handles Telegram API errors" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendAudio")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: audio URL not found"
        }))
      end)

      assert {:error, "Failed to send audio: Bad Request: audio URL not found (HTTP 400)"} =
               SendAudio.handler(
                 %{
                   chat_id: @chat_id,
                   audio: "https://example.com/invalid.mp3",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendAudio.view()
      assert prism.input_schema.required == ["chat_id", "audio"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :audio)
      assert Map.has_key?(prism.input_schema.properties, :caption)
      assert Map.has_key?(prism.input_schema.properties, :parse_mode)
      assert Map.has_key?(prism.input_schema.properties, :duration)
      assert Map.has_key?(prism.input_schema.properties, :performer)
      assert Map.has_key?(prism.input_schema.properties, :title)
    end

    test "validates output schema" do
      prism = SendAudio.view()
      assert prism.output_schema.required == ["sent", "message_id"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :audio)
      assert Map.has_key?(prism.output_schema.properties, :caption)
    end
  end
end
