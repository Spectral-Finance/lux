defmodule Lux.Prisms.YouTube.StartLiveBroadcastTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.StartLiveBroadcast
  alias Lux.Integrations.YouTube.Client

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, Client})
    Application.put_env(:lux, :api_keys, [youtube_api_key: "test_api_key"])
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "creates broadcast, stream, and binds them" do
      # 1. create_broadcast
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts"
        Req.Test.json(conn, %{"id" => "broadcast123"})
      end)

      # 2. create_stream
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveStreams"
        Req.Test.json(conn, %{"id" => "stream123"})
      end)

      # 3. bind_broadcast
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts/bind"
        query = URI.decode_query(conn.query_string)
        assert query["id"] == "broadcast123"
        assert query["streamId"] == "stream123"
        
        Req.Test.json(conn, %{"id" => "broadcast123", "status" => %{"lifeCycleStatus" => "ready"}})
      end)

      params = %{
        title: "Test Broadcast",
        description: "A test broadcast",
        scheduled_start_time: "2024-01-01T00:00:00Z",
        dry_run: false
      }
      
      assert {:ok, result} = StartLiveBroadcast.handler(params, nil)
      assert result.broadcast_id == "broadcast123"
      assert result.stream_id == "stream123"
      assert result.bind_response["status"]["lifeCycleStatus"] == "ready"
    end
  end
end
