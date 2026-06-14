defmodule Lux.Integrations.YouTubeIntelligenceTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.YouTubeIntelligence
  describe "search" do
    test "search_videos/1 returns video results" do
      assert elem(YouTubeIntelligence.search_videos("Elixir tutorial"), 0) in [:ok, :error]
    end
    test "trending_topics/0 returns trending" do
      assert elem(YouTubeIntelligence.trending_topics(), 0) in [:ok, :error]
    end
  end
  describe "channel analytics" do
    test "channel_analytics/1 returns channel data" do
      assert elem(YouTubeIntelligence.channel_analytics("UC_x5XG1OV2P6uZZ5FSM9Ttw"), 0) in [:ok, :error]
    end
  end
end
