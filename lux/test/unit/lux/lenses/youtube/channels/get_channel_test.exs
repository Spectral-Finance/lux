defmodule Lux.Lenses.YouTube.Channels.GetChannelTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.Channels.GetChannel

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "gets channel details by ID" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/channels"
      query = URI.decode_query(conn.query_string)
      assert query["id"] == "UC_test_channel"
      assert query["part"] == "snippet,statistics"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "items" => [
            %{
              "id" => "UC_test_channel",
              "snippet" => %{
                "title" => "Test Channel",
                "description" => "A channel",
                "customUrl" => "@test",
                "publishedAt" => "2026-01-01T00:00:00Z"
              },
              "statistics" => %{
                "subscriberCount" => "10",
                "videoCount" => "2",
                "viewCount" => "100"
              }
            }
          ]
        })
      )
    end)

    assert {:ok, %{id: "UC_test_channel", title: "Test Channel", subscriber_count: "10"}} =
             GetChannel.focus(%{channel_id: "UC_test_channel"}, %{})
  end

  test "returns channel_not_found when YouTube returns no channel" do
    Req.Test.expect(Lux.Lens, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
    end)

    assert {:error, :channel_not_found} = GetChannel.focus(%{channel_id: "missing"}, %{})
  end
end
