defmodule Lux.Prisms.YouTube.UpdateBroadcastStatusTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.UpdateBroadcastStatus
  alias Lux.Integrations.YouTube.Client

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, Client})
    Application.put_env(:lux, :api_keys, [youtube_api_key: "test_api_key"])
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "transitions a broadcast status" do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts/transition"
        
        query = URI.decode_query(conn.query_string)
        assert query["id"] == "broadcast123"
        assert query["broadcastStatus"] == "live"
        
        Req.Test.json(conn, %{"id" => "broadcast123", "status" => %{"lifeCycleStatus" => "live"}})
      end)

      params = %{broadcast_id: "broadcast123", status: "live", dry_run: false}
      
      assert {:ok, result} = UpdateBroadcastStatus.handler(params, nil)
      assert result["status"]["lifeCycleStatus"] == "live"
    end
  end
end
