defmodule Lux.Integrations.YouTube.LiveStreamTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.LiveStream

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, Client})
    Req.Test.verify_on_exit!()
    
    %{
      config: %Client.Config{
        api_key: "test_api_key",
        access_token: nil,
        dry_run: false
      }
    }
  end

  describe "create_broadcast/2" do
    test "creates a live broadcast", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts"
        assert conn.query_string == "key=test_api_key&part=snippet%2Cstatus%2CcontentDetails"
        
        {:ok, body, _} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["snippet"]["title"] == "Test Broadcast"
        
        Req.Test.json(conn, %{"id" => "broadcast123"})
      end)

      assert {:ok, result} = LiveStream.create_broadcast(%{
        title: "Test Broadcast"
      }, config)
      
      assert result["id"] == "broadcast123"
    end
  end

  describe "create_stream/2" do
    test "creates a live stream", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveStreams"
        
        {:ok, body, _} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["cdn"]["resolution"] == "1080p"
        
        Req.Test.json(conn, %{"id" => "stream123"})
      end)

      assert {:ok, result} = LiveStream.create_stream(%{
        title: "Test Stream",
        resolution: "1080p"
      }, config)
      
      assert result["id"] == "stream123"
    end
  end

  describe "bind_broadcast/3" do
    test "binds a stream to a broadcast", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts/bind"
        assert conn.query_string =~ "id=broadcast123"
        assert conn.query_string =~ "streamId=stream123"
        
        Req.Test.json(conn, %{"id" => "broadcast123", "status" => %{"lifeCycleStatus" => "ready"}})
      end)

      assert {:ok, result} = LiveStream.bind_broadcast("broadcast123", "stream123", config)
      assert result["status"]["lifeCycleStatus"] == "ready"
    end
  end

  describe "transition_broadcast/3" do
    test "transitions a broadcast status", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts/transition"
        assert conn.query_string =~ "broadcastStatus=testing"
        assert conn.query_string =~ "id=broadcast123"
        
        Req.Test.json(conn, %{"id" => "broadcast123", "status" => %{"lifeCycleStatus" => "testing"}})
      end)

      assert {:ok, result} = LiveStream.transition_broadcast("broadcast123", "testing", config)
      assert result["status"]["lifeCycleStatus"] == "testing"
    end
  end

  describe "get_stream_health/2" do
    test "gets the health status of a stream", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/liveStreams"
        assert conn.query_string =~ "id=stream123"
        assert conn.query_string =~ "part=status"
        
        Req.Test.json(conn, %{
          "items" => [
            %{"status" => %{"healthStatus" => %{"status" => "good"}}}
          ]
        })
      end)

      assert {:ok, result} = LiveStream.get_stream_health("stream123", config)
      assert result["status"] == "good"
    end
  end
end
