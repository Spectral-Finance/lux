defmodule Lux.Lenses.YouTube.Analytics.GetChannelPerformanceTest do
  @moduledoc """
  Test suite for the GetChannelPerformance lens.
  Verifies the lens can:
  - Retrieve channel statistics and compute growth indicators
  - Classify subscriber tier and content maturity
  - Handle not found (empty items) responses
  - Handle YouTube API errors
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Analytics.GetChannelPerformance

  @channel_id "UCxxxxxxxxxxxxxx"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves channel performance with growth indicators" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [%{
            "id" => @channel_id,
            "snippet" => %{
              "title" => "ElixirPros",
              "description" => "Best Elixir tutorials",
              "customUrl" => "@elixirpros",
              "country" => "US",
              "publishedAt" => "2020-01-01T00:00:00Z"
            },
            "statistics" => %{
              "subscriberCount" => "75000",
              "viewCount" => "5000000",
              "videoCount" => "150",
              "hiddenSubscriberCount" => false
            },
            "brandingSettings" => %{
              "channel" => %{"keywords" => "elixir phoenix programming"}
            }
          }]
        }))
      end)

      assert {:ok, result} = GetChannelPerformance.focus(%{"channel_id" => @channel_id}, %{})
      assert result.channel_id == @channel_id
      assert result.title == "ElixirPros"
      assert result.subscriber_count == 75_000
      assert result.total_views == 5_000_000
      assert result.video_count == 150
      assert result.avg_views_per_video == 33_333
      assert result.growth_indicators.subscriber_tier == "mid_tier"
      assert result.growth_indicators.content_maturity == "established"
      assert result.growth_indicators.views_per_subscriber == 66.67
    end

    test "classifies mega channel correctly" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [%{
            "id" => "UCmega",
            "snippet" => %{"title" => "MegaChannel"},
            "statistics" => %{
              "subscriberCount" => "5000000",
              "viewCount" => "500000000",
              "videoCount" => "1000"
            },
            "brandingSettings" => %{"channel" => %{}}
          }]
        }))
      end)

      assert {:ok, result} = GetChannelPerformance.focus(%{"channel_id" => "UCmega"}, %{})
      assert result.growth_indicators.subscriber_tier == "mega"
      assert result.growth_indicators.content_maturity == "veteran"
    end

    test "returns error when channel is not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:error, %{message: "Channel not found", code: "CHANNEL_NOT_FOUND"}} =
               GetChannelPerformance.focus(%{"channel_id" => "UCnonexistent"}, %{})
    end

    test "returns error for YouTube API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "error" => %{"code" => 403, "message" => "Access denied"}
        }))
      end)

      assert {:error, %{message: "Access denied", code: 403}} =
               GetChannelPerformance.focus(%{"channel_id" => @channel_id}, %{})
    end
  end

  describe "after_focus/1" do
    test "handles zero video count without division error" do
      response = %{
        "items" => [%{
          "id" => "UCnew",
          "snippet" => %{"title" => "New Channel"},
          "statistics" => %{
            "subscriberCount" => "100",
            "viewCount" => "0",
            "videoCount" => "0"
          },
          "brandingSettings" => %{"channel" => %{}}
        }]
      }

      assert {:ok, result} = GetChannelPerformance.after_focus(response)
      assert result.avg_views_per_video == 0
      assert result.growth_indicators.content_maturity == "starter"
      assert result.growth_indicators.subscriber_tier == "micro"
    end

    test "returns error for unexpected response" do
      assert {:error, %{message: "Unexpected response"}} =
               GetChannelPerformance.after_focus(%{"unexpected" => true})
    end
  end

  describe "schema validation" do
    test "requires channel_id field" do
      lens = GetChannelPerformance.view()
      assert lens.schema.required == ["channel_id"]
    end

    test "uses GET method" do
      lens = GetChannelPerformance.view()
      assert lens.method == :get
    end

    test "targets YouTube channels endpoint" do
      lens = GetChannelPerformance.view()
      assert lens.url == "https://www.googleapis.com/youtube/v3/channels"
    end
  end
end
