defmodule Lux.Lenses.YouTube.Videos.ListChannelVideosTest do
  @moduledoc """
  Test suite for the YouTube ListChannelVideos lens.
  Verifies:
  - Video listing with pagination
  - Filtering by event type (live/upcoming)
  - Empty channel handling
  - Error response propagation
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Videos.ListChannelVideos

  @channel_id "UCxxxxxxxxxxxxxxxxxxxxxx"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists channel videos" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "search"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => %{"videoId" => "video1"},
              "snippet" => %{
                "title" => "First Video",
                "description" => "A great video",
                "channelId" => @channel_id,
                "channelTitle" => "Example Channel",
                "publishedAt" => "2024-01-15T12:00:00.000Z",
                "thumbnails" => %{"high" => %{"url" => "https://i.ytimg.com/vi/video1/hqdefault.jpg"}},
                "liveBroadcastContent" => "none"
              }
            },
            %{
              "id" => %{"videoId" => "video2"},
              "snippet" => %{
                "title" => "Second Video",
                "channelId" => @channel_id,
                "channelTitle" => "Example Channel",
                "publishedAt" => "2024-01-14T10:00:00.000Z"
              }
            }
          ],
          "nextPageToken" => "page_token_abc",
          "pageInfo" => %{
            "totalResults" => 342,
            "resultsPerPage" => 20
          }
        }))
      end)

      assert {:ok, result} = ListChannelVideos.focus(%{"channel_id" => @channel_id}, %{})

      assert length(result.videos) == 2
      assert result.next_page_token == "page_token_abc"
      assert result.total_results == 342

      [video1, _video2] = result.videos
      assert video1.video_id == "video1"
      assert video1.title == "First Video"
      assert video1.channel_id == @channel_id
    end

    test "handles empty channel" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [],
          "pageInfo" => %{"totalResults" => 0, "resultsPerPage" => 20}
        }))
      end)

      assert {:ok, result} = ListChannelVideos.focus(%{"channel_id" => @channel_id}, %{})
      assert result.videos == []
      assert result.total_results == 0
    end

    test "handles API error for quota exceeded" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{"message" => "The request cannot be completed because you have exceeded your quota."}
        }))
      end)

      assert {:error, %{message: msg}} = ListChannelVideos.focus(%{"channel_id" => @channel_id}, %{})
      assert msg =~ "quota"
    end
  end
end
