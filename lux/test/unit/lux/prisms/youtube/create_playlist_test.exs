defmodule Lux.Prisms.YouTube.CreatePlaylistTest do
  @moduledoc """
  Test suite for the CreatePlaylist prism.
  These tests verify the prism's ability to:
  - Prepare valid playlist creation request payloads
  - Validate required parameters (title, privacy_status)
  - Reject invalid privacy status values
  - Include optional fields when provided
  - Return correct API endpoint and OAuth scope information
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.CreatePlaylist

  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "successfully prepares a public playlist creation request" do
      assert {:ok, result} =
               CreatePlaylist.handler(
                 %{
                   "title" => "My Coding Tutorials",
                   "description" => "A collection of programming tutorials",
                   "privacy_status" => "public",
                   "tags" => ["coding", "tutorial", "programming"]
                 },
                 @agent_ctx
               )

      assert result.api_endpoint == "https://www.googleapis.com/youtube/v3/playlists"
      assert result.http_method == "POST"
      assert result.query_params == %{part: "snippet,status"}
      assert "https://www.googleapis.com/auth/youtube" in result.required_scopes

      assert result.playlist_data.snippet.title == "My Coding Tutorials"
      assert result.playlist_data.snippet.description == "A collection of programming tutorials"
      assert result.playlist_data.snippet.tags == ["coding", "tutorial", "programming"]
      assert result.playlist_data.status.privacy_status == "public"
    end

    test "creates a private playlist without tags" do
      assert {:ok, result} =
               CreatePlaylist.handler(
                 %{
                   "title" => "Private Drafts",
                   "privacy_status" => "private"
                 },
                 @agent_ctx
               )

      assert result.playlist_data.snippet.title == "Private Drafts"
      assert result.playlist_data.snippet.tags == []
      assert result.playlist_data.status.privacy_status == "private"
    end

    test "creates an unlisted playlist" do
      assert {:ok, result} =
               CreatePlaylist.handler(
                 %{"title" => "Unlisted Series", "privacy_status" => "unlisted"},
                 @agent_ctx
               )

      assert result.playlist_data.status.privacy_status == "unlisted"
    end

    test "includes default_language when provided" do
      assert {:ok, result} =
               CreatePlaylist.handler(
                 %{
                   "title" => "Spanish Tutorials",
                   "privacy_status" => "public",
                   "default_language" => "es"
                 },
                 @agent_ctx
               )

      assert result.playlist_data.snippet.default_language == "es"
    end

    test "returns error for missing title" do
      assert {:error, message} =
               CreatePlaylist.handler(
                 %{"privacy_status" => "public"},
                 @agent_ctx
               )

      assert String.contains?(message, "title")
    end

    test "returns error for empty title" do
      assert {:error, message} =
               CreatePlaylist.handler(
                 %{"title" => "", "privacy_status" => "public"},
                 @agent_ctx
               )

      assert String.contains?(message, "empty")
    end

    test "returns error for missing privacy_status" do
      assert {:error, message} =
               CreatePlaylist.handler(
                 %{"title" => "My Playlist"},
                 @agent_ctx
               )

      assert String.contains?(message, "privacy_status")
    end

    test "returns error for invalid privacy_status" do
      assert {:error, message} =
               CreatePlaylist.handler(
                 %{"title" => "My Playlist", "privacy_status" => "secret"},
                 @agent_ctx
               )

      assert String.contains?(message, "secret")
    end

    test "returns error for title exceeding 100 characters" do
      long_title = String.duplicate("a", 101)

      assert {:error, message} =
               CreatePlaylist.handler(
                 %{"title" => long_title, "privacy_status" => "public"},
                 @agent_ctx
               )

      assert String.contains?(message, "100")
    end
  end
end
