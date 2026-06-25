defmodule Lux.Prisms.Twitter.UploadMediaTest do
  @moduledoc """
  Test suite for the UploadMedia prism.
  """

  use UnitAPICase, async: true

  alias Lux.Prisms.Twitter.UploadMedia
  alias Lux.Integrations.Telegram.Client, as: TelegramClient

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully uploads raw image data" do
      image_data = <<0x89, 0x50, 0x4E, 0x47>> <> "fake_png_data"

      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.starts_with?(conn.request_path, "https://upload.twitter.com")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "media_id_string" => "media_abc123xyz",
          "media_key" => "3_media_abc123xyz"
        }))
      end)

      assert {:ok, %{media_id: "media_abc123xyz", media_type: "image/png"}} =
               UploadMedia.handler(%{
                 media_data: image_data,
                 media_type: "image/png"
               }, @agent_ctx)
    end

    test "successfully uploads base64-encoded data" do
      original_data = "hello image data"
      encoded = Base.encode64(original_data)

      Req.Test.expect(TwitterClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body == original_data

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "media_id_string" => "media_def456",
          "media_key" => "3_media_def456"
        }))
      end)

      assert {:ok, %{media_id: "media_def456"}} =
               UploadMedia.handler(%{
                 media_data: encoded,
                 media_type: "image/png",
                 encoding: "base64"
               }, @agent_ctx)
    end

    test "handles upload failure" do
      image_data = <<0xFF, 0xD8, 0xFF>> <> "fake_jpeg"

      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "title" => "Invalid Media",
          "detail" => "The media data could not be processed"
        }))
      end)

      assert {:error, {400, %{"title" => _, "detail" => _}}} =
               UploadMedia.handler(%{
                 media_data: image_data,
                 media_type: "image/jpeg"
               }, @agent_ctx)
    end

    test "rejects missing required fields" do
      assert {:error, "Missing or invalid media_data"} =
               UploadMedia.handler(%{media_type: "image/png"}, @agent_ctx)

      assert {:error, "Missing or invalid media_type"} =
               UploadMedia.handler(%{media_data: "data"}, @agent_ctx)
    end
  end
end
