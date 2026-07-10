defmodule Lux.Lenses.YouTube.ListPlaylistsTest do
  @moduledoc """
  Test suite for the ListPlaylists module.
  These tests verify the lens's ability to:
  - List playlists from a YouTube channel
  - Handle YouTube API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.ListPlaylists

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists playlists" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/playlists"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "PLlrATfBNZ7893w5u",
              "snippet" => %{
                "title" => "Elixir Series",
                "description" => "A series on Elixir",
                "channelTitle" => "ElixirCasts",
                "publishedAt" => "2024-01-01T00:00:00Z",
                "thumbnails" => %{
                  "default" => %{"url" => "https://i.ytimg.com/vi/abc/default.jpg"}
                }
              },
              "contentDetails" => %{
                "itemCount" => 15
              }
            },
            %{
              "id" => "PLxyz789abc",
              "snippet" => %{
                "title" => "Phoenix Tutorials",
                "description" => "Building with Phoenix",
                "channelTitle" => "ElixirCasts",
                "publishedAt" => "2024-03-01T00:00:00Z",
                "thumbnails" => %{
                  "default" => %{"url" => "https://i.ytimg.com/vi/xyz/default.jpg"}
                }
              },
              "contentDetails" => %{
                "itemCount" => 8
              }
            }
          ]
        }))
      end)

      assert {:ok, [
        %{
          playlist_id: "PLlrATfBNZ7893w5u",
          title: "Elixir Series",
          description: "A series on Elixir",
          channel_title: "ElixirCasts",
          published_at: "2024-01-01T00:00:00Z",
          item_count: 15,
          thumbnail_url: "https://i.ytimg.com/vi/abc/default.jpg"
        },
        %{
          playlist_id: "PLxyz789abc",
          title: "Phoenix Tutorials",
          description: "Building with Phoenix",
          channel_title: "ElixirCasts",
          published_at: "2024-03-01T00:00:00Z",
          item_count: 8,
          thumbnail_url: "https://i.ytimg.com/vi/xyz/default.jpg"
        }
      ]} = ListPlaylists.focus(%{
        "channelId" => "UCsBjURrPoezykLs9EqgamOA"
      }, %{})
    end

    test "handles YouTube API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/playlists"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{
            "message" => "The request is not properly authorized"
          }
        }))
      end)

      assert {:error, %{"error" => %{"message" => "The request is not properly authorized"}}} = ListPlaylists.focus(%{
        "channelId" => "UCsBjURrPoezykLs9EqgamOA"
      }, %{})
    end
  end
end
