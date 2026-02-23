defmodule Lux.Lenses.YouTube.Community.GetChannelSectionsTest do
  @moduledoc """
  Test suite for the GetChannelSections lens.
  These tests verify the lens's ability to:
  - Retrieve channel sections for a given channel ID
  - Handle sections with playlists and featured channels
  - Process YouTube API error responses
  - Return structured section data
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Community.GetChannelSections

  @channel_id "UCxxxxxxxxxxxxxx"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves channel sections" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/channelSections"

        query = URI.decode_query(conn.query_string)
        assert query["channelId"] == @channel_id
        assert query["part"] == "snippet,contentDetails"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "items" => [
              %{
                "id" => "section_001",
                "snippet" => %{
                  "channelId" => @channel_id,
                  "title" => "Featured Playlists",
                  "type" => "singlePlaylist",
                  "position" => 0
                },
                "contentDetails" => %{
                  "playlists" => ["PLxxxxxxxxxx"],
                  "channels" => []
                }
              }
            ]
          })
        )
      end)

      assert {:ok, result} = GetChannelSections.focus(%{channel_id: @channel_id}, %{})
      assert result.count == 1
      [section] = result.sections
      assert section.id == "section_001"
      assert section.channel_id == @channel_id
      assert section.title == "Featured Playlists"
      assert section.type == "singlePlaylist"
      assert section.position == 0
      assert section.playlist_ids == ["PLxxxxxxxxxx"]
      assert section.channel_ids == []
    end

    test "handles sections with featured channels" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "items" => [
              %{
                "id" => "section_002",
                "snippet" => %{
                  "channelId" => @channel_id,
                  "type" => "channels",
                  "position" => 1
                },
                "contentDetails" => %{
                  "channels" => ["UCfeatured1", "UCfeatured2"]
                }
              }
            ]
          })
        )
      end)

      assert {:ok, result} = GetChannelSections.focus(%{channel_id: @channel_id}, %{})
      [section] = result.sections
      assert section.channel_ids == ["UCfeatured1", "UCfeatured2"]
    end

    test "handles empty channel sections" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:ok, result} = GetChannelSections.focus(%{channel_id: @channel_id}, %{})
      assert result.sections == []
      assert result.count == 0
    end

    test "handles YouTube API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          403,
          Jason.encode!(%{
            "error" => %{"message" => "Channel not found"}
          })
        )
      end)

      assert {:error, %{message: "Channel not found"}} =
               GetChannelSections.focus(%{channel_id: @channel_id}, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = GetChannelSections.view()
      assert lens.schema.required == ["channel_id"]
    end

    test "validates hl parameter" do
      lens = GetChannelSections.view()
      assert lens.schema.properties.hl.type == :string
    end
  end
end
