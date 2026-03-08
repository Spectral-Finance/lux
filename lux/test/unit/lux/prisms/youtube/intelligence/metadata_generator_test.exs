defmodule Lux.Prisms.YouTube.Intelligence.MetadataGeneratorTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.YouTube.Intelligence.MetadataGenerator

  describe "description generation" do
    test "generates full description" do
      assert {:ok, result} =
               MetadataGenerator.handler(
                 %{
                   action: "description",
                   topic: "Elixir OTP Guide",
                   key_points: ["GenServer basics", "Supervision trees", "Application structure"],
                   niche: "programming",
                   links: %{"GitHub" => "https://github.com/example"},
                   social_links: %{twitter: "https://twitter.com/example"}
                 },
                 []
               )

      assert result.has_cta == true
      assert result.has_hashtags == true
      assert String.contains?(result.description, "Elixir OTP Guide")
      assert String.contains?(result.description, "GenServer basics")
      assert String.contains?(result.description, "Subscribe")
    end
  end

  describe "chapter generation" do
    test "generates chapters from key points" do
      assert {:ok, result} =
               MetadataGenerator.handler(
                 %{
                   action: "chapters",
                   topic: "Test",
                   key_points: ["Setup", "Configuration", "Testing", "Deployment"],
                   duration_minutes: 20
                 },
                 []
               )

      assert result.count >= 4
      assert hd(result.chapters).timestamp == "0:00"
      assert hd(result.chapters).label == "Introduction"
      assert String.contains?(result.text, "0:00")
    end

    test "handles fewer than 2 key points" do
      assert {:ok, result} =
               MetadataGenerator.handler(
                 %{action: "chapters", topic: "Test", key_points: ["Only one"]},
                 []
               )

      assert result.chapters == []
    end
  end

  describe "cards suggestion" do
    test "suggests info cards" do
      assert {:ok, result} =
               MetadataGenerator.handler(
                 %{
                   action: "cards",
                   topic: "Test",
                   key_points: ["Point A", "Point B", "Point C"],
                   duration_minutes: 15
                 },
                 []
               )

      assert length(result.cards) == 3
      assert result.max_allowed == 5

      [first | _] = result.cards
      assert first.type == "video"
      assert first.timestamp_seconds > 0
    end
  end

  describe "end screen suggestion" do
    test "suggests end screen elements" do
      assert {:ok, result} =
               MetadataGenerator.handler(
                 %{
                   action: "end_screen",
                   topic: "Elixir Tutorial",
                   niche: "programming",
                   duration_minutes: 10
                 },
                 []
               )

      assert length(result.elements) == 3
      types = Enum.map(result.elements, & &1.type)
      assert "subscribe" in types
      assert "best_for_viewer" in types
    end
  end
end
