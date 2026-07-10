defmodule Lux.Lenses.YouTube.SearchVideosTest do
  @moduledoc """
  Test suite for the SearchVideos module.
  These tests verify the lens's ability to:
  - Search for YouTube videos
  - Handle YouTube API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.SearchVideos

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully searches for videos" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/search"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => %{"videoId" => "abc123"},
              "snippet" => %{
                "title" => "Learn Elixir",
                "description" => "A great tutorial",
                "channelTitle" => "ElixirCasts",
                "publishedAt" => "2024-01-01T00:00:00Z",
                "thumbnails" => %{
                  "default" => %{"url" => "https://i.ytimg.com/vi/abc123/default.jpg"}
                }
              }
            },
            %{
              "id" => %{"videoId" => "def456"},
              "snippet" => %{
                "title" => "Elixir Phoenix",
                "description" => "Build web apps",
                "channelTitle" => "CodeSchool",
                "publishedAt" => "2024-02-01T00:00:00Z",
                "thumbnails" => %{
                  "default" => %{"url" => "https://i.ytimg.com/vi/def456/default.jpg"}
                }
              }
            }
          ]
        }))
      end)

      assert {:ok, [
        %{
          video_id: "abc123",
          title: "Learn Elixir",
          description: "A great tutorial",
          channel_title: "ElixirCasts",
          published_at: "2024-01-01T00:00:00Z",
          thumbnail_url: "https://i.ytimg.com/vi/abc123/default.jpg"
        },
        %{
          video_id: "def456",
          title: "Elixir Phoenix",
          description: "Build web apps",
          channel_title: "CodeSchool",
          published_at: "2024-02-01T00:00:00Z",
          thumbnail_url: "https://i.ytimg.com/vi/def456/default.jpg"
        }
      ]} = SearchVideos.focus(%{
        "q" => "elixir programming",
        "max_results" => 5
      }, %{})
    end

    test "handles YouTube API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/search"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{
            "message" => "Daily Limit Exceeded"
          }
        }))
      end)

      assert {:error, %{"error" => %{"message" => "Daily Limit Exceeded"}}} = SearchVideos.focus(%{
        "q" => "elixir programming"
      }, %{})
    end
  end
end
