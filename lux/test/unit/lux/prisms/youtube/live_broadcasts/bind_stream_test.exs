defmodule Lux.Prisms.YouTube.LiveBroadcasts.BindStreamTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client
  alias Lux.Prisms.YouTube.LiveBroadcasts.BindStream

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, YouTubeClientMock})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "binds a stream to a live broadcast" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveBroadcasts/bind"
      query = URI.decode_query(conn.query_string)
      assert query["id"] == "broadcast-123"
      assert query["streamId"] == "stream-123"
      assert query["part"] == "id,contentDetails"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-123", "contentDetails" => %{"boundStreamId" => "stream-123"}}))
    end)

    assert {:ok, %{id: "broadcast-123", bound_stream_id: "stream-123"}} =
             BindStream.handler(%{id: "broadcast-123", stream_id: "stream-123"}, %{name: "Agent"})
  end
end
