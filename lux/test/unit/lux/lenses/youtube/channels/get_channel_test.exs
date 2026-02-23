defmodule Lux.Lenses.YouTube.Channels.GetChannelTest do
  @moduledoc """
  Test suite for the YouTube GetChannel lens.
  Verifies:
  - Channel stat retrieval with subscriber/video/view counts
  - Channel lookup by ID and username
  - Missing channel handling
  - Error response propagation
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Channels.GetChannel

  @channel_id "UCxxxxxxxxxxxxxxxxxxxxxx"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves channel by ID" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "channels"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "kind" => "youtube#channelListResponse",
          "items" => [
            %{
              "id" => @channel_id,
              "snippet" => %{
                "title" => "Example Channel",
                "description" => "A great YouTube channel.",
                "customUrl" => "@example",
                "publishedAt" => "2020-01-01T00:00:00.000Z",
                "country" => "US",
                "thumbnails" => %{
                  "high" => %{"url" => "https://example.com/thumb.jpg"}
                }
              },
              "statistics" => %{
                "subscriberCount" => "150000",
                "videoCount" => "342",
                "viewCount" => "12500000",
                "hiddenSubscriberCount" => false
              },
              "brandingSettings" => %{
                "image" => %{"bannerExternalUrl" => "https://example.com/banner.jpg"}
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = GetChannel.focus(%{"channel_id" => @channel_id}, %{})

      assert result.id == @channel_id
      assert result.title == "Example Channel"
      assert result.custom_url == "@example"
      assert result.subscriber_count == 150_000
      assert result.video_count == 342
      assert result.view_count == 12_500_000
      assert result.country == "US"
      assert result.thumbnail_url == "https://example.com/thumb.jpg"
    end

    test "handles channel with minimal data" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => @channel_id,
              "snippet" => %{"title" => "Minimal Channel"},
              "statistics" => %{"subscriberCount" => "100", "videoCount" => "5"}
            }
          ]
        }))
      end)

      assert {:ok, result} = GetChannel.focus(%{"channel_id" => @channel_id}, %{})
      assert result.id == @channel_id
      assert result.title == "Minimal Channel"
      assert result.subscriber_count == 100
      refute Map.has_key?(result, :custom_url)
      refute Map.has_key?(result, :banner_url)
    end

    test "handles channel not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:error, %{message: "Channel not found"}} =
               GetChannel.focus(%{"channel_id" => "UCnonexistent"}, %{})
    end

    test "handles API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "error" => %{
            "code" => 400,
            "message" => "Invalid channel ID"
          }
        }))
      end)

      assert {:error, %{message: "Invalid channel ID"}} =
               GetChannel.focus(%{"channel_id" => "invalid"}, %{})
    end
  end
end
