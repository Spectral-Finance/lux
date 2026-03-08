defmodule Lux.Prisms.YouTube.PlaylistOrganizerTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.PlaylistOrganizer

  setup do
    name = :"playlist_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = PlaylistOrganizer.start_link(name: name)
    %{pid: pid}
  end

  test "create playlist", %{pid: pid} do
    {:ok, pl} = PlaylistOrganizer.create_playlist(pid, %{title: "Tutorials"})
    assert pl.title == "Tutorials"
    assert pl.videos == []
  end

  test "add video to playlist", %{pid: pid} do
    {:ok, pl} = PlaylistOrganizer.create_playlist(pid, %{title: "Series"})
    {:ok, updated} = PlaylistOrganizer.add_video(pid, pl.id, %{id: "v1", title: "Part 1"})
    assert length(updated.videos) == 1
  end

  test "remove video", %{pid: pid} do
    {:ok, pl} = PlaylistOrganizer.create_playlist(pid, %{title: "T"})
    {:ok, _} = PlaylistOrganizer.add_video(pid, pl.id, %{id: "v1", title: "V1"})
    {:ok, updated} = PlaylistOrganizer.remove_video(pid, pl.id, "v1")
    assert updated.videos == []
  end

  test "reorder video", %{pid: pid} do
    {:ok, pl} = PlaylistOrganizer.create_playlist(pid, %{title: "T"})
    {:ok, _} = PlaylistOrganizer.add_video(pid, pl.id, %{id: "v1", title: "V1"})
    {:ok, _} = PlaylistOrganizer.add_video(pid, pl.id, %{id: "v2", title: "V2"})
    {:ok, updated} = PlaylistOrganizer.reorder(pid, pl.id, "v2", 0)
    assert hd(updated.videos).video_id == "v2"
  end

  test "list playlists", %{pid: pid} do
    {:ok, _} = PlaylistOrganizer.create_playlist(pid, %{title: "A"})
    {:ok, _} = PlaylistOrganizer.create_playlist(pid, %{title: "B"})
    {:ok, list} = PlaylistOrganizer.list_playlists(pid)
    assert length(list) == 2
  end

  test "not found playlist", %{pid: pid} do
    assert {:error, :not_found} = PlaylistOrganizer.get_playlist(pid, "nope")
  end

  test "auto categorize", %{pid: pid} do
    videos = [
      %{id: "v1", title: "Learn Elixir", tags: ["tutorial", "elixir"]},
      %{id: "v2", title: "iPhone 17 Review", tags: ["review", "iphone"]},
      %{id: "v3", title: "My Day", tags: ["vlog", "daily"]}
    ]
    {:ok, categories} = PlaylistOrganizer.auto_categorize(pid, videos)
    assert Map.has_key?(categories, :tutorials)
    assert Map.has_key?(categories, :reviews)
    assert Map.has_key?(categories, :vlogs)
  end
end
