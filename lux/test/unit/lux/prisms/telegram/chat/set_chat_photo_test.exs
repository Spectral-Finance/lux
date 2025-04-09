defmodule Lux.Prisms.Telegram.Chat.SetChatPhotoTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Chat.SetChatPhoto

  @chat_id 123_456_789
  @photo "https://example.com/chat_photo.jpg"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets a chat photo with required parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/setChatPhoto")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["photo"] == @photo

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, result} =
        SetChatPhoto.handler(
          %{
            chat_id: @chat_id,
            photo: @photo,
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )

      assert result.success == true
      assert result.chat_id == @chat_id
    end

    test "successfully sets a chat photo for a channel" do
      channel_username = "@testchannel"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/setChatPhoto")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == channel_username
        assert decoded_body["photo"] == @photo

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, result} =
        SetChatPhoto.handler(
          %{
            chat_id: channel_username,
            photo: @photo,
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )

      assert result.success == true
      assert result.chat_id == channel_username
    end

    test "validates required parameters" do
      result = SetChatPhoto.handler(%{photo: @photo}, @agent_ctx)
      assert result == {:error, "Missing or invalid chat_id"}

      result = SetChatPhoto.handler(%{chat_id: @chat_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid photo"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/setChatPhoto")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: not enough rights to change chat photo"
        }))
      end)

      assert {:error, "Failed to set chat photo: Bad Request: not enough rights to change chat photo (HTTP 400)"} =
        SetChatPhoto.handler(
          %{
            chat_id: @chat_id,
            photo: @photo,
            plug: {Req.Test, __MODULE__}
          },
          @agent_ctx
        )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SetChatPhoto.view()
      assert prism.input_schema.required == ["chat_id", "photo"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :photo)
    end

    test "validates output schema" do
      prism = SetChatPhoto.view()
      assert prism.output_schema.required == ["success", "chat_id"]
      assert Map.has_key?(prism.output_schema.properties, :success)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
    end
  end
end
