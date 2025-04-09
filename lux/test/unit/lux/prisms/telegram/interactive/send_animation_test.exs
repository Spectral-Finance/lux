defmodule Lux.Prisms.Telegram.Interactive.SendAnimationTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.SendAnimation

  @chat_id 123_456_789
  @animation "https://example.com/animation.gif"
  @message_id 42
  @caption "Check out this GIF"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends an animation with required parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendAnimation")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["animation"] == @animation

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 111_222_333, "is_bot" => true, "first_name" => "Test Bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_609_459_200,
            "animation" => %{
              "file_id" => "CgACAgQAAxkBAAIBZ2TvQR6TZRlP2k4SaTJJ0XhXuG6xAAL8DAACuRSYUqRxeL-sYu4pMAQ",
              "file_unique_id" => "AgAD_AwAArk4mFI",
              "width" => 320,
              "height" => 240,
              "duration" => 5,
              "thumb" => %{
                "file_id" => "AAMCBAADGQEAAgFnZO9BHpNlGU_aThJpMknReFeAgsAArwwAArk4mFJSUf72ZtPkJgEAB20AAzAE",
                "file_unique_id" => "AQAD_AwAArk4mFJy",
                "width" => 320,
                "height" => 240,
                "file_size" => 12_345
              },
              "file_name" => "animation.gif",
              "mime_type" => "image/gif",
              "file_size" => 54_321
            }
          }
        }))
      end)

      assert {:ok, result} =
        SendAnimation.handler(
          %{
            chat_id: @chat_id,
            animation: @animation,
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )

      assert result.sent == true
      assert result.message_id == @message_id
      assert result.chat_id == @chat_id
      assert result.animation == @animation
      assert result.caption == nil
    end

    test "successfully sends an animation with caption and other optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendAnimation")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["animation"] == @animation
        assert decoded_body["caption"] == @caption
        assert decoded_body["parse_mode"] == "Markdown"
        assert decoded_body["duration"] == 5
        assert decoded_body["width"] == 320
        assert decoded_body["height"] == 240
        assert decoded_body["has_spoiler"] == true
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
        SendAnimation.handler(
          %{
            chat_id: @chat_id,
            animation: @animation,
            caption: @caption,
            parse_mode: "Markdown",
            duration: 5,
            width: 320,
            height: 240,
            has_spoiler: true,
            disable_notification: true,
            protect_content: true,
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )

      assert result.sent == true
      assert result.message_id == @message_id
      assert result.chat_id == @chat_id
      assert result.animation == @animation
      assert result.caption == @caption
    end

    test "validates required parameters" do
      result = SendAnimation.handler(%{animation: @animation}, @agent_ctx)
      assert result == {:error, "Missing or invalid chat_id"}

      result = SendAnimation.handler(%{chat_id: @chat_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid animation"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendAnimation")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: invalid animation URL provided"
        }))
      end)

      assert {:error, "Failed to send animation: Bad Request: invalid animation URL provided (HTTP 400)"} =
        SendAnimation.handler(
          %{
            chat_id: @chat_id,
            animation: "invalid_url",
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendAnimation.view()
      assert prism.input_schema.required == ["chat_id", "animation"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :animation)
      assert Map.has_key?(prism.input_schema.properties, :caption)
      assert Map.has_key?(prism.input_schema.properties, :parse_mode)
      assert Map.has_key?(prism.input_schema.properties, :duration)
      assert Map.has_key?(prism.input_schema.properties, :width)
      assert Map.has_key?(prism.input_schema.properties, :height)
      assert Map.has_key?(prism.input_schema.properties, :has_spoiler)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
      assert Map.has_key?(prism.input_schema.properties, :protect_content)
    end

    test "validates output schema" do
      prism = SendAnimation.view()
      assert prism.output_schema.required == ["sent", "message_id"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :animation)
      assert Map.has_key?(prism.output_schema.properties, :caption)
    end
  end
end
