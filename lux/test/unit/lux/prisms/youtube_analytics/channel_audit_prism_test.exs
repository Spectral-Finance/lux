defmodule Lux.Prisms.YoutubeAnalytics.ChannelAuditPrismTest do
  use ExUnit.Case, async: true
  doctest Lux.Prisms.YoutubeAnalytics.ChannelAuditPrism

  describe "transform/1" do
    test "has correct prism metadata" do
      assert Lux.Prisms.YoutubeAnalytics.ChannelAuditPrism.__meta__(:name) == "YouTube Channel Audit"
    end

    test "performs audit with valid data" do
      assert {:ok, result} = Lux.Prisms.YoutubeAnalytics.ChannelAuditPrism.transform(%{
        channel_metrics: %{subscriber_count: 5000, view_count: 50000, video_count: 50},
        recent_videos: []
      })

      assert result.audit_score != nil
      assert result.grade != nil
      assert result.categories != nil
      assert result.recommendations != nil
    end

    test "grades channel correctly" do
      assert {:ok, %{grade: grade}} = Lux.Prisms.YoutubeAnalytics.ChannelAuditPrism.transform(%{
        channel_metrics: %{subscriber_count: 500},
        recent_videos: []
      })
      assert grade in ["A", "B", "C", "D", "F"]
    end

    test "identifies issues for low-scoring categories" do
      assert {:ok, result} = Lux.Prisms.YoutubeAnalytics.ChannelAuditPrism.transform(%{
        channel_metrics: %{subscriber_count: 100},
        recent_videos: []
      })
      assert result.issues != nil
    end
  end
end
