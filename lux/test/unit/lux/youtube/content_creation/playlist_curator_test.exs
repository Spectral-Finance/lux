defmodule Lux.YouTube.ContentCreation.PlaylistCuratorTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentCreation.PlaylistCurator

  describe "curate_series/2" do
    test "sequences videos pedagogically from foundation to production" do
      videos = [
        "Advanced Agent Production Benchmarks",
        "Introduction to Lux Framework",
        "Step-by-Step Agent Tutorial",
        "Testing and Debugging Supervision Trees"
      ]

      playlist = PlaylistCurator.curate_series("Lux Agent Mastery", videos)

      assert String.contains?(playlist.playlist_title, "Lux Agent Mastery")
      assert length(playlist.ordered_videos) == 4

      # Verify pedagogical sequencing
      first = Enum.at(playlist.ordered_videos, 0)
      assert String.contains?(first.title, "Introduction")
      assert first.position == 1

      last = Enum.at(playlist.ordered_videos, 3)
      assert String.contains?(last.title, "Advanced")
      assert last.position == 4
    end
  end
end
