defmodule Lux.Prisms.Telegram.Interactive.SendStickerTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.SendSticker

  @chat_id 123_456_789
  @sticker "CAACAgIAAxkBAAEBpF5jX-qMJzJxcjTg_nJQdl"
  @message_id 42
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends a sticker with required parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendSticker")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["sticker"] == @sticker

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 111_222_333, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_609_459_200,
            "sticker" => %{
              "file_id" => @sticker,
              "file_unique_id" => "AgADcwIAAuQWZRc",
              "width" => 512,
              "height" => 512,
              "is_animated" => false,
              "is_video" => false,
              "type" => "regular",
              "thumb" => %{
                "file_id" => "AAQCAAOmEAACZCmpS3JLjk2zYdLbAQAB",
                "file_unique_id" => "AQADphAAAk8mqUty",
                "width" => 128,
                "height" => 128,
                "file_size" => 4246
              },
              "file_size" => 17214
            }
          }
        }))
      end)

      assert {:ok, result} =
        SendSticker.handler(
          %{
            chat_id: @chat_id,
            sticker: @sticker,
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )

      assert result.sent == true
      assert result.message_id == @message_id
      assert result.chat_id == @chat_id
      assert result.sticker == @sticker
    end

    test "successfully sends a sticker with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendSticker")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["sticker"] == @sticker
        assert decoded_body["emoji"] == "😊"
        assert decoded_body["disable_notification"] == true
        assert decoded_body["protect_content"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id
          }
        }))
      end)

      assert {:ok, result} =
        SendSticker.handler(
          %{
            chat_id: @chat_id,
            sticker: @sticker,
            emoji: "😊",
            disable_notification: true,
            protect_content: true,
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )

      assert result.sent == true
      assert result.message_id == @message_id
      assert result.chat_id == @chat_id
      assert result.sticker == @sticker
    end

    test "validates required parameters" do
      result = SendSticker.handler(%{sticker: @sticker}, @agent_ctx)
      assert result == {:error, "Missing or invalid chat_id"}

      result = SendSticker.handler(%{chat_id: @chat_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid sticker"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendSticker")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: sticker not found"
        }))
      end)

      assert {:error, "Failed to send sticker: Bad Request: sticker not found (HTTP 400)"} =
        SendSticker.handler(
          %{
            chat_id: @chat_id,
            sticker: "invalid_sticker_id",
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendSticker.view()
      assert prism.input_schema.required == ["chat_id", "sticker"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :sticker)
      assert Map.has_key?(prism.input_schema.properties, :emoji)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
      assert Map.has_key?(prism.input_schema.properties, :protect_content)
    end

    test "validates output schema" do
      prism = SendSticker.view()
      assert prism.output_schema.required == ["sent", "message_id"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :sticker)
    end
  end
end
