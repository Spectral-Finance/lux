defmodule Lux.Prisms.YouTube.ManageStreamTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.ManageStream

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "creates stream" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.request_path == "/youtube/v3/liveStreams"
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
        "id" => "stream1",
        "snippet" => %{"title" => "Stream"},
        "cdn" => %{
          "ingestionInfo" => %{"ingestionAddress" => "rtmp://server", "streamName" => "key"}
        },
        "status" => %{"streamStatus" => "active"}
      }))
    end)

    assert {:ok, %{stream_id: "stream1"}} =
      ManageStream.handler(%{action: "create", title: "Stream", access_token: "token", plug: {Req.Test, YouTubeClientMock}}, %{})
  end

  test "deletes stream" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.request_path == "/youtube/v3/liveStreams"
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{}))
    end)

    assert {:ok, %{deleted: true}} =
      ManageStream.handler(%{action: "delete", stream_id: "stream1", access_token: "token", plug: {Req.Test, YouTubeClientMock}}, %{})
  end
end
