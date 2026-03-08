defmodule Lux.Lenses.YouTube.Intelligence.TrendingAnalysisTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.YouTube.Intelligence.TrendingAnalysis

  describe "categories/0" do
    test "returns YouTube categories" do
      cats = TrendingAnalysis.categories()
      assert Map.has_key?(cats, "20")
      assert cats["20"] == "Gaming"
      assert cats["28"] == "Science & Technology"
    end
  end

  describe "focus/2 content_gaps" do
    test "analyzes content gaps from video list" do
      videos = [
        %{title: "Best Python Tutorial for Beginners"},
        %{title: "Python Machine Learning Guide"},
        %{title: "Advanced Python Tips and Tricks"},
        %{title: "Python Web Development with Django"},
        %{title: "Python Data Science Complete Course"}
      ]

      assert {:ok, result} =
               TrendingAnalysis.focus(%{
                 action: "content_gaps",
                 videos: videos
               })

      assert result.total_videos_analyzed == 5
      assert length(result.common_topics) > 0

      topics = Enum.map(result.common_topics, & &1.topic)
      assert "python" in topics
    end

    test "handles empty video list" do
      assert {:ok, result} =
               TrendingAnalysis.focus(%{action: "content_gaps", videos: []})

      assert result.total_videos_analyzed == 0
    end
  end
end
