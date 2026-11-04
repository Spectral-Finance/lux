defmodule Lux.YouTube.ContentIntelligence.ConcurrencyTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence

  @valid_video_data %{
    views: 10_000,
    watch_time_minutes: 5000,
    video_length_seconds: 600,
    likes: 500,
    comments: 50,
    shares: 25,
    published_at: ~U[2024-01-01 12:00:00Z],
    current_time: ~U[2024-01-02 12:00:00Z]
  }

  describe "concurrency" do
    test "handles concurrent analyze_video calls without shared state corruption" do
      tasks = Enum.map(1..10, fn _ ->
        Task.async(fn ->
          ContentIntelligence.analyze_video(@valid_video_data)
        end)
      end)

      results = Enum.map(tasks, &Task.await/1)

      Enum.each(results, fn result ->
        assert {:ok, _} = result
        assert Map.has_key?(elem(result, 1), :performance)
        assert Map.has_key?(elem(result, 1), :engagement)
      end)
    end

    test "handles concurrent performance calls" do
      tasks = Enum.map(1..5, fn i ->
        Task.async(fn ->
          ContentIntelligence.analyze_video(%{@valid_video_data | views: i * 1000})
        end)
      end)

      results = Enum.map(tasks, &Task.await/1)

      Enum.each(results, fn result ->
        assert {:ok, _} = result
      end)
    end

    test "handles concurrent prism calls" do
      alias Lux.Prisms.YouTubeContentIntelligencePrism

      tasks = Enum.map(1..5, fn i ->
        Task.async(fn ->
          YouTubeContentIntelligencePrism.run(%{
            "action" => "performance",
            "video_data" => %{@valid_video_data | views: i * 1000}
          }, nil)
        end)
      end)

      results = Enum.map(tasks, &Task.await/1)

      Enum.each(results, fn result ->
        assert {:ok, _} = result
      end)
    end
  end
end