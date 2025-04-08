defmodule Lux.Prisms.Telegram.Media.SendVoiceTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Media.SendVoice

  @chat_id 123_456_789
  @voice_url "https://example.com/voice.ogg"
  @voice_file_id "AgACAgQAAxkBAAIBZWCtPW7GcS9llxJh7SZqAAAAH-E5tQACrroxG6gS0FHr9bwF"
  @message_id 42
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends voice by URL" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendVoice")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["voice"] == @voice_url

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id},
            "voice" => %{"file_id" => "abc123"}
          }
        }))
      end)

      assert {:ok,
              %{
                sent: true,
                message_id: @message_id,
                chat_id: @chat_id,
                voice: @voice_url
              }} =
               SendVoice.handler(
                 %{
                   chat_id: @chat_id,
                   voice: @voice_url,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends voice by file_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendVoice")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["voice"] == @voice_file_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id},
            "voice" => %{"file_id" => @voice_file_id}
          }
        }))
      end)

      assert {:ok,
              %{
                sent: true,
                message_id: @message_id,
                chat_id: @chat_id,
                voice: @voice_file_id
              }} =
               SendVoice.handler(
                 %{
                   chat_id: @chat_id,
                   voice: @voice_file_id,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends voice with markdown caption" do
      caption = "*Bold* and _italic_ caption"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendVoice")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["voice"] == @voice_url
        assert decoded_body["caption"] == caption
        assert decoded_body["parse_mode"] == "Markdown"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id},
            "voice" => %{"file_id" => "abc123"},
            "caption" => caption
          }
        }))
      end)

      assert {:ok,
              %{
                sent: true,
                message_id: @message_id,
                chat_id: @chat_id,
                voice: @voice_url,
                caption: ^caption
              }} =
               SendVoice.handler(
                 %{
                   chat_id: @chat_id,
                   voice: @voice_url,
                   caption: caption,
                   parse_mode: "Markdown",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends voice with optional parameters" do
      duration = 60

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendVoice")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["voice"] == @voice_url
        assert decoded_body["duration"] == duration

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id},
            "voice" => %{
              "file_id" => "abc123",
              "duration" => duration
            }
          }
        }))
      end)

      assert {:ok,
              %{
                sent: true,
                message_id: @message_id,
                chat_id: @chat_id,
                voice: @voice_url
              }} =
               SendVoice.handler(
                 %{
                   chat_id: @chat_id,
                   voice: @voice_url,
                   duration: duration,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates required parameters" do
      assert {:error, "Missing or invalid chat_id"} =
               SendVoice.handler(
                 %{
                   voice: @voice_url
                 },
                 @agent_ctx
               )

      assert {:error, "Missing or invalid voice"} =
               SendVoice.handler(
                 %{
                   chat_id: @chat_id
                 },
                 @agent_ctx
               )
    end

    test "handles Telegram API errors" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendVoice")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: voice URL not found"
        }))
      end)

      assert {:error, "Failed to send voice message: Bad Request: voice URL not found (HTTP 400)"} =
               SendVoice.handler(
                 %{
                   chat_id: @chat_id,
                   voice: "https://example.com/invalid.ogg",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendVoice.view()
      assert prism.input_schema.required == ["chat_id", "voice"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :voice)
      assert Map.has_key?(prism.input_schema.properties, :caption)
      assert Map.has_key?(prism.input_schema.properties, :parse_mode)
      assert Map.has_key?(prism.input_schema.properties, :duration)
    end

    test "validates output schema" do
      prism = SendVoice.view()
      assert prism.output_schema.required == ["sent", "message_id"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :voice)
      assert Map.has_key?(prism.output_schema.properties, :caption)
    end
  end
end
