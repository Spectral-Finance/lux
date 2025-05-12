defmodule Lux.Prisms.Telegram.Media.SendMediaGroupTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Media.SendMediaGroup

  @bot_token "test-integration-telegram-bot-token"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "sends a media group with photos" do
      chat_id = 123_456_789
      media = [
        %{
          type: "photo",
          media: "https://example.com/photo1.jpg",
          caption: "First photo"
        },
        %{
          type: "photo",
          media: "https://example.com/photo2.jpg",
          caption: "Second photo"
        }
      ]

      Req.Test.expect(TelegramClientMock, fn request ->
        assert request.method == "POST"
        assert request.request_path == "/bot#{@bot_token}/sendMediaGroup"

        {:ok, body, _request} = Plug.Conn.read_body(request)
        decoded_body = Jason.decode!(body)
        assert decoded_body == %{
          "chat_id" => chat_id,
          "media" => [
            %{
              "type" => "photo",
              "media" => "https://example.com/photo1.jpg",
              "caption" => "First photo"
            },
            %{
              "type" => "photo",
              "media" => "https://example.com/photo2.jpg",
              "caption" => "Second photo"
            }
          ]
        }

        request
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "message_id" => 42,
              "chat" => %{"id" => chat_id},
              "photo" => [%{"file_id" => "photo1_file_id"}]
            },
            %{
              "message_id" => 43,
              "chat" => %{"id" => chat_id},
              "photo" => [%{"file_id" => "photo2_file_id"}]
            }
          ]
        }))
      end)

      result = SendMediaGroup.handler(
        %{
          chat_id: chat_id,
          media: media
        },
        %{name: "TestAgent", plug: {Req.Test, __MODULE__}}
      )

      assert {:ok, %{sent: true, message_ids: [42, 43], chat_id: ^chat_id}} = result
    end

    test "sends a media group with mixed media types" do
      chat_id = 123_456_789
      media = [
        %{
          type: "photo",
          media: "https://example.com/photo.jpg",
          caption: "A photo"
        },
        %{
          type: "video",
          media: "https://example.com/video.mp4",
          caption: "A video"
        },
        %{
          type: "document",
          media: "https://example.com/doc.pdf",
          caption: "A document"
        }
      ]

      Req.Test.expect(TelegramClientMock, fn request ->
        assert request.method == "POST"
        assert request.request_path == "/bot#{@bot_token}/sendMediaGroup"

        {:ok, body, _request} = Plug.Conn.read_body(request)
        decoded_body = Jason.decode!(body)
        assert decoded_body == %{
          "chat_id" => chat_id,
          "media" => [
            %{
              "type" => "photo",
              "media" => "https://example.com/photo.jpg",
              "caption" => "A photo"
            },
            %{
              "type" => "video",
              "media" => "https://example.com/video.mp4",
              "caption" => "A video"
            },
            %{
              "type" => "document",
              "media" => "https://example.com/doc.pdf",
              "caption" => "A document"
            }
          ]
        }

        request
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "message_id" => 42,
              "chat" => %{"id" => chat_id},
              "photo" => [%{"file_id" => "photo_file_id"}]
            },
            %{
              "message_id" => 43,
              "chat" => %{"id" => chat_id},
              "video" => %{"file_id" => "video_file_id"}
            },
            %{
              "message_id" => 44,
              "chat" => %{"id" => chat_id},
              "document" => %{"file_id" => "document_file_id"}
            }
          ]
        }))
      end)

      result = SendMediaGroup.handler(
        %{
          chat_id: chat_id,
          media: media
        },
        %{name: "TestAgent", plug: {Req.Test, __MODULE__}}
      )

      assert {:ok, %{sent: true, message_ids: [42, 43, 44], chat_id: ^chat_id}} = result
    end

    test "validates media group size" do
      chat_id = 123_456_789

      # Test with single item
      result = SendMediaGroup.handler(
        %{
          chat_id: chat_id,
          media: [
            %{
              type: "photo",
              media: "https://example.com/photo.jpg"
            }
          ]
        },
        %{name: "TestAgent", plug: {Req.Test, __MODULE__}}
      )

      assert {:error, "Media group must contain at least 2 items"} = result

      # Test with too many items
      media = for i <- 1..11 do
        %{
          type: "photo",
          media: "https://example.com/photo#{i}.jpg"
        }
      end

      result = SendMediaGroup.handler(
        %{
          chat_id: chat_id,
          media: media
        },
        %{name: "TestAgent", plug: {Req.Test, __MODULE__}}
      )

      assert {:error, "Media group cannot contain more than 10 items"} = result
    end

    test "validates media item types" do
      chat_id = 123_456_789

      result = SendMediaGroup.handler(
        %{
          chat_id: chat_id,
          media: [
            %{
              type: "invalid_type",
              media: "https://example.com/file1.jpg"
            },
            %{
              type: "photo",
              media: "https://example.com/photo2.jpg"
            }
          ]
        },
        %{name: "TestAgent", plug: {Req.Test, __MODULE__}}
      )

      assert {:error, "Invalid media items in the group"} = result
    end

    test "handles API errors" do
      error_description = "Bad Request: media invalid"

      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => error_description
        }))
      end)

      result = SendMediaGroup.handler(
        %{
          chat_id: 123_456_789,
          media: [
            %{
              type: "photo",
              media: "https://example.com/photo1.jpg"
            },
            %{
              type: "photo",
              media: "https://example.com/photo2.jpg"
            }
          ]
        },
        %{name: "TestAgent", plug: {Req.Test, __MODULE__}}
      )

      expected_error = "Failed to send media group: #{error_description} (HTTP 400)"
      assert {:error, ^expected_error} = result
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendMediaGroup.view()

      assert prism.input_schema.type == :object
      assert prism.input_schema.required == ["chat_id", "media"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :media)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
      assert Map.has_key?(prism.input_schema.properties, :protect_content)
      assert Map.has_key?(prism.input_schema.properties, :reply_to_message_id)
      assert Map.has_key?(prism.input_schema.properties, :allow_sending_without_reply)
    end

    test "validates output schema" do
      prism = SendMediaGroup.view()

      assert prism.output_schema.type == :object
      assert prism.output_schema.required == ["sent", "message_ids", "chat_id"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_ids)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
    end
  end
end
