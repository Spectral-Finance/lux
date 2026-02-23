defmodule Lux.Lenses.YouTube.Creation.ListPlaylistItemsTest do
  @moduledoc """
  Test suite for the ListPlaylistItems lens.
  These tests verify the lens's ability to:
  - List videos within a YouTube playlist
  - Handle empty playlist item results
  - Handle YouTube API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Creation.ListPlaylistItems

  @playlist_id "PLxxxxxxxxxxxxxxxxxxxxxx"
  @video_id "dQw4w9WgXcQ"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists items in a playlist" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/playlistItems"

        query = URI.decode_query(conn.query_string)
        assert query["playlistId"] == @playlist_id
        assert query["part"] == "snippet,contentDetails"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "kind" => "youtube#playlistItemListResponse",
          "pageInfo" => %{"totalResults" => 1},
          "items" => [
            %{
              "id" => "UExxxxxxxxxxxxxxxxxxxxxQ",
              "snippet" => %{
                "title" => "Never Gonna Give You Up",
                "description" => "Official music video",
                "publishedAt" => "2009-10-25T06:57:33Z",
                "channelTitle" => "Rick Astley",
                "playlistId" => @playlist_id,
                "position" => 0,
                "resourceId" => %{
                  "kind" => "youtube#video",
                  "videoId" => @video_id
                },
                "thumbnails" => %{
                  "high" => %{"url" => "https://i.ytimg.com/vi/#{@video_id}/hqdefault.jpg"}
                }
              },
              "contentDetails" => %{"videoId" => @video_id}
            }
          ]
        }))
      end)

      assert {:ok, result} = ListPlaylistItems.focus(%{"playlist_id" => @playlist_id}, %{})
      assert result.count == 1
      assert result.playlist_id == @playlist_id
      [item] = result.items
      assert item.video_id == @video_id
      assert item.title == "Never Gonna Give You Up"
      assert item.position == 0
      assert item.channel_title == "Rick Astley"
    end

    test "handles empty playlist" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/playlistItems"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "kind" => "youtube#playlistItemListResponse",
          "pageInfo" => %{"totalResults" => 0},
          "items" => []
        }))
      end)

      assert {:ok, result} = ListPlaylistItems.focus(%{"playlist_id" => @playlist_id}, %{})
      assert result.items == []
      assert result.count == 0
    end

    test "handles YouTube API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/playlistItems"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "error" => %{
            "code" => 404,
            "message" => "Playlist not found",
            "status" => "NOT_FOUND"
          }
        }))
      end)

      assert {:error, %{message: "Playlist not found", code: 404}} =
               ListPlaylistItems.focus(%{"playlist_id" => @playlist_id}, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = ListPlaylistItems.view()
      assert lens.schema.required == ["playlist_id"]
    end

    test "validates schema properties" do
      lens = ListPlaylistItems.view()
      assert Map.has_key?(lens.schema.properties, :playlist_id)
      assert Map.has_key?(lens.schema.properties, :max_results)
      assert lens.schema.properties.playlist_id.type == :string
    end
  end
end
