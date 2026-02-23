defmodule Lux.Lenses.YouTube.Growth.ListTopVideosTest do
  @moduledoc """
  Test suite for the YouTube ListTopVideos lens.
  Verifies:
  - Trending video retrieval with engagement metrics
  - Optional region and category filtering
  - Empty results handling
  - API error propagation
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Growth.ListTopVideos

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves top videos with engagement metrics" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "videos"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "abc123xyz",
              "snippet" => %{
                "title" => "Most Popular Song",
                "channelTitle" => "MusicChannel",
                "channelId" => "UCmusic",
                "publishedAt" => "2024-01-10T00:00:00.000Z",
                "thumbnails" => %{"high" => %{"url" => "https://i.ytimg.com/vi/abc123xyz/hqdefault.jpg"}}
              },
              "statistics" => %{
                "viewCount" => "8000000",
                "likeCount" => "500000",
                "commentCount" => "20000"
              }
            }
          ],
          "pageInfo" => %{"totalResults" => 50}
        }))
      end)

      assert {:ok, %{videos: [video], total_results: 50}} =
               ListTopVideos.focus(%{"region_code" => "US", "max_results" => 1}, %{})

      assert video.id == "abc123xyz"
      assert video.title == "Most Popular Song"
      assert video.channel_title == "MusicChannel"
      assert video.view_count == 8_000_000
      assert video.like_count == 500_000
      assert video.comment_count == 20_000
      assert video.engagement_rate == Float.round((500_000 + 20_000) / 8_000_000 * 100, 2)
    end

    test "returns empty list when no videos found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [],
          "pageInfo" => %{"totalResults" => 0}
        }))
      end)

      assert {:ok, %{videos: [], total_results: 0}} =
               ListTopVideos.focus(%{}, %{})
    end

    test "handles API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{"message" => "Daily quota exceeded"}
        }))
      end)

      assert {:error, %{message: "Daily quota exceeded"}} =
               ListTopVideos.focus(%{"region_code" => "US"}, %{})
    end

    test "correctly computes engagement_rate as zero when view_count is zero" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "zeroViews1",
              "snippet" => %{
                "title" => "New Video",
                "channelTitle" => "NewChan",
                "channelId" => "UCnew"
              },
              "statistics" => %{
                "viewCount" => "0",
                "likeCount" => "0",
                "commentCount" => "0"
              }
            }
          ],
          "pageInfo" => %{"totalResults" => 1}
        }))
      end)

      assert {:ok, %{videos: [video]}} = ListTopVideos.focus(%{}, %{})
      assert video.engagement_rate == 0.0
    end
  end

  describe "schema validation" do
    test "validates schema properties" do
      lens = ListTopVideos.view()
      assert Map.has_key?(lens.schema.properties, :region_code)
      assert Map.has_key?(lens.schema.properties, :video_category_id)
      assert Map.has_key?(lens.schema.properties, :max_results)
      assert lens.schema.required == []
    end
  end
end
