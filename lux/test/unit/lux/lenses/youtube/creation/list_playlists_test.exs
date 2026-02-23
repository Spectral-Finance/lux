defmodule Lux.Lenses.YouTube.Creation.ListPlaylistsTest do
  @moduledoc """
  Test suite for the ListPlaylists lens.
  These tests verify the lens's ability to:
  - List playlists for a YouTube channel
  - Handle empty playlist results
  - Handle YouTube API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Creation.ListPlaylists

  @channel_id "UCxxxxxx1234567890"
  @playlist_id "PLxxxxxxxxxxxxxxxxxxxxxx"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists playlists for a channel" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/playlists"

        query = URI.decode_query(conn.query_string)
        assert query["channelId"] == @channel_id
        assert query["part"] == "snippet,contentDetails,status"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "kind" => "youtube#playlistListResponse",
          "items" => [
            %{
              "id" => @playlist_id,
              "snippet" => %{
                "title" => "My Best Videos",
                "description" => "A curated collection",
                "channelId" => @channel_id,
                "publishedAt" => "2024-01-01T00:00:00Z",
                "thumbnails" => %{
                  "high" => %{"url" => "https://i.ytimg.com/vi/thumbnail.jpg"}
                }
              },
              "contentDetails" => %{"itemCount" => 42},
              "status" => %{"privacyStatus" => "public"}
            }
          ]
        }))
      end)

      assert {:ok, result} = ListPlaylists.focus(%{"channel_id" => @channel_id}, %{})
      assert result.count == 1
      [playlist] = result.playlists
      assert playlist.id == @playlist_id
      assert playlist.title == "My Best Videos"
      assert playlist.description == "A curated collection"
      assert playlist.channel_id == @channel_id
      assert playlist.item_count == 42
      assert playlist.privacy_status == "public"
      assert playlist.thumbnail_url == "https://i.ytimg.com/vi/thumbnail.jpg"
    end

    test "handles empty playlist result" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/playlists"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "kind" => "youtube#playlistListResponse",
          "items" => []
        }))
      end)

      assert {:ok, result} = ListPlaylists.focus(%{"channel_id" => @channel_id}, %{})
      assert result.playlists == []
      assert result.count == 0
    end

    test "handles YouTube API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/playlists"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{
            "code" => 403,
            "message" => "The caller does not have permission",
            "status" => "PERMISSION_DENIED"
          }
        }))
      end)

      assert {:error, %{message: "The caller does not have permission", code: 403}} =
               ListPlaylists.focus(%{"channel_id" => @channel_id}, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = ListPlaylists.view()
      assert lens.schema.required == ["channel_id"]
    end

    test "validates schema properties" do
      lens = ListPlaylists.view()
      assert Map.has_key?(lens.schema.properties, :channel_id)
      assert Map.has_key?(lens.schema.properties, :max_results)
      assert lens.schema.properties.channel_id.type == :string
      assert lens.schema.properties.max_results.type == :integer
    end
  end
end
