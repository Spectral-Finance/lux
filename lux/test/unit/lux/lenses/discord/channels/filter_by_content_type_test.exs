defmodule Lux.Lenses.Discord.Channels.FilterByContentTypeTest do
  @moduledoc """
  Test suite for the FilterByContentType module.
  These tests verify the lens's ability to:
  - Filter messages by content type (images, files, etc.)
  - Handle specific file type filtering
  - Process Discord API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Channels.FilterByContentType

  @channel_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully filters messages by image content type" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["has"] == "images"
        assert query["limit"] == "50"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "id" => "987654321",
            "content" => "Check out this image!",
            "author" => %{
              "id" => "444555666",
              "username" => "artist"
            },
            "timestamp" => "2024-04-03T12:00:00.000000+00:00",
            "attachments" => [
              %{
                "id" => "111222333",
                "filename" => "artwork.png",
                "content_type" => "image/png",
                "size" => 1_048_576,
                "url" => "https://cdn.discordapp.com/attachments/123/456/artwork.png"
              }
            ],
            "embeds" => []
          }
        ]))
      end)

      assert {:ok, [message]} = FilterByContentType.focus(%{
        channel_id: @channel_id,
        content_type: "images"
      }, %{})

      assert message.id == "987654321"
      assert message.content == "Check out this image!"
      assert message.author.username == "artist"
      assert [attachment] = message.attachments
      assert attachment.filename == "artwork.png"
      assert attachment.content_type == "image/png"
    end

    test "successfully filters messages by file type" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["has"] == "files.pdf"
        assert query["limit"] == "50"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "id" => "987654321",
            "content" => "Here's the document",
            "author" => %{
              "id" => "444555666",
              "username" => "user"
            },
            "timestamp" => "2024-04-03T12:00:00.000000+00:00",
            "attachments" => [
              %{
                "id" => "111222333",
                "filename" => "document.pdf",
                "content_type" => "application/pdf",
                "size" => 2_048_576,
                "url" => "https://cdn.discordapp.com/attachments/123/456/document.pdf"
              }
            ],
            "embeds" => []
          }
        ]))
      end)

      assert {:ok, [message]} = FilterByContentType.focus(%{
        channel_id: @channel_id,
        content_type: "files",
        file_type: "pdf"
      }, %{})

      assert message.id == "987654321"
      assert [attachment] = message.attachments
      assert attachment.filename == "document.pdf"
      assert attachment.content_type == "application/pdf"
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} = FilterByContentType.focus(%{
        channel_id: @channel_id,
        content_type: "images"
      }, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = FilterByContentType.view()
      assert lens.schema.required == ["channel_id", "content_type"]
    end

    test "validates content type enum" do
      lens = FilterByContentType.view()
      content_type = lens.schema.properties.content_type
      assert content_type.type == :string
      assert Enum.sort(content_type.enum) == Enum.sort(["attachments", "embeds", "files", "links", "videos", "images"])
    end

    test "validates file type pattern" do
      lens = FilterByContentType.view()
      file_type = lens.schema.properties.file_type
      assert file_type.type == :string
      assert file_type.pattern == "^[a-zA-Z0-9]+$"
    end
  end
end
