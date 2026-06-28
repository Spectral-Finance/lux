defmodule Lux.Lenses.YouTube.CheckStreamHealthTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.CheckStreamHealth
  alias Lux.Integrations.YouTube.Client

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

  describe "focus/3" do
    test "returns the stream health status" do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/liveStreams"
        
        query = URI.decode_query(conn.query_string)
        assert query["id"] == "stream123"
        
        Req.Test.json(conn, %{
          "items" => [
            %{"status" => %{"healthStatus" => %{"status" => "good"}}}
          ]
        })
      end)

      params = %{stream_id: "stream123"}

      assert {:ok, result} = CheckStreamHealth.focus(params, nil)
      
      assert result.health_status["status"] == "good"
    end
  end
end
