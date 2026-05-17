defmodule Lux.Lenses.YouTube.Channels.ListChannelsTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.Channels.ListChannels

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "lists and normalizes channel metadata" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/channels"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-youtube-token"]

      query = URI.decode_query(conn.query_string)
      assert query["mine"] == "true"
      assert query["part"] == "snippet,contentDetails,statistics"
      assert query["maxResults"] == "2"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "items" => [
            %{
              "id" => "UC123",
              "snippet" => %{
                "title" => "Lux Channel",
                "description" => "Agent demos",
                "customUrl" => "@lux"
              },
              "contentDetails" => %{
                "relatedPlaylists" => %{"uploads" => "UU123"}
              },
              "statistics" => %{
                "viewCount" => "1000",
                "subscriberCount" => "42",
                "videoCount" => "7"
              }
            }
          ]
        })
      )
    end)

    assert {:ok, [channel]} = ListChannels.focus(%{mine: true, max_results: 2})
    assert channel.id == "UC123"
    assert channel.title == "Lux Channel"
    assert channel.uploads_playlist_id == "UU123"
    assert channel.subscriber_count == 42
  end

  test "schema exposes lookup filters" do
    lens = ListChannels.view()
    assert Map.has_key?(lens.schema.properties, :mine)
    assert Map.has_key?(lens.schema.properties, :id)
    assert Map.has_key?(lens.schema.properties, :for_username)
  end
end
