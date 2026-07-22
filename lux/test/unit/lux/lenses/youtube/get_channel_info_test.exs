defmodule Lux.Lenses.YouTube.GetChannelInfoTest do
  @moduledoc """
  Test suite for the GetChannelInfo module.
  These tests verify the lens's ability to:
  - Fetch channel information from YouTube
  - Handle missing channels
  - Handle YouTube API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.GetChannelInfo

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches channel info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/channels"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "UCsBjURrPoezykLs9EqgamOA",
              "snippet" => %{
                "title" => "Fireship",
                "description" => "High-intensity code tutorials",
                "customUrl" => "@fireship",
                "publishedAt" => "2017-01-01T00:00:00Z",
                "thumbnails" => %{
                  "default" => %{"url" => "https://yt3.ggpht.com/fireship.jpg"}
                }
              },
              "statistics" => %{
                "subscriberCount" => "2000000",
                "videoCount" => "500",
                "viewCount" => "200000000"
              }
            }
          ]
        }))
      end)

      assert {:ok, %{
        channel_id: "UCsBjURrPoezykLs9EqgamOA",
        title: "Fireship",
        description: "High-intensity code tutorials",
        custom_url: "@fireship",
        published_at: "2017-01-01T00:00:00Z",
        subscriber_count: "2000000",
        video_count: "500",
        view_count: "200000000",
        thumbnail_url: "https://yt3.ggpht.com/fireship.jpg"
      }} = GetChannelInfo.focus(%{
        "id" => "UCsBjURrPoezykLs9EqgamOA"
      }, %{})
    end

    test "handles channel not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/channels"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => []
        }))
      end)

      assert {:error, %{"message" => "Channel not found"}} = GetChannelInfo.focus(%{
        "id" => "nonexistent_channel"
      }, %{})
    end

    test "handles YouTube API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/channels"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{
            "message" => "API key not valid"
          }
        }))
      end)

      assert {:error, %{"error" => %{"message" => "API key not valid"}}} = GetChannelInfo.focus(%{
        "id" => "UCsBjURrPoezykLs9EqgamOA"
      }, %{})
    end
  end
end
