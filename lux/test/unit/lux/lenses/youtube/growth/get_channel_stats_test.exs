defmodule Lux.Lenses.YouTube.Growth.GetChannelStatsTest do
  @moduledoc """
  Test suite for the YouTube GetChannelStats lens.
  Verifies:
  - Full channel statistics retrieval
  - Avg views per video computation
  - Monetization hints from branding settings
  - Channel not found handling
  - API error propagation
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Growth.GetChannelStats

  @channel_id "UCxxxxxx123"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves full channel stats with monetization hints" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "channels"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => @channel_id,
              "snippet" => %{
                "title" => "Tech Insights",
                "description" => "Weekly tech deep-dives",
                "publishedAt" => "2016-01-01T00:00:00.000Z",
                "country" => "US",
                "thumbnails" => %{"high" => %{"url" => "https://yt3.ggpht.com/tech.jpg"}}
              },
              "statistics" => %{
                "subscriberCount" => "120000",
                "viewCount" => "9600000",
                "videoCount" => "320",
                "hiddenSubscriberCount" => false
              },
              "brandingSettings" => %{
                "channel" => %{
                  "keywords" => "tech programming software engineering"
                }
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = GetChannelStats.focus(%{"channel_id" => @channel_id}, %{})

      assert result.id == @channel_id
      assert result.title == "Tech Insights"
      assert result.subscriber_count == 120_000
      assert result.view_count == 9_600_000
      assert result.video_count == 320
      assert result.avg_views_per_video == 30_000
      assert result.country == "US"
      assert result.hidden_subscriber_count == false
      assert result.monetization_hints.has_keywords == true
      assert result.monetization_hints.keywords == "tech programming software engineering"
    end

    test "returns channel not found error for empty items list" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:error, %{message: "Channel not found"}} =
               GetChannelStats.focus(%{"channel_id" => "UCnonexistent"}, %{})
    end

    test "handles API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{"message" => "The caller does not have permission"}
        }))
      end)

      assert {:error, %{message: "The caller does not have permission"}} =
               GetChannelStats.focus(%{"channel_id" => @channel_id}, %{})
    end

    test "handles missing branding settings gracefully" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => @channel_id,
              "snippet" => %{
                "title" => "Minimal Channel",
                "publishedAt" => "2020-05-01T00:00:00.000Z"
              },
              "statistics" => %{
                "subscriberCount" => "5000",
                "viewCount" => "250000",
                "videoCount" => "50"
              },
              "brandingSettings" => %{}
            }
          ]
        }))
      end)

      assert {:ok, result} = GetChannelStats.focus(%{"channel_id" => @channel_id}, %{})
      assert result.subscriber_count == 5_000
      assert result.monetization_hints.has_keywords == false
      assert result.monetization_hints.keywords == nil
    end
  end

  describe "schema validation" do
    test "requires channel_id" do
      lens = GetChannelStats.view()
      assert "channel_id" in lens.schema.required
      assert Map.has_key?(lens.schema.properties, :channel_id)
    end
  end
end
