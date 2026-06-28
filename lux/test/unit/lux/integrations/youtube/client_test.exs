defmodule Lux.Integrations.YouTube.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, Client})
    Req.Test.verify_on_exit!()
    
    # Return a clean config for testing
    %{
      config: %Client.Config{
        api_key: "test_api_key",
        access_token: nil,
        dry_run: false
      }
    }
  end

  describe "get/3" do
    test "makes a GET request with API key", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/channels"
        assert conn.query_string == "key=test_api_key&part=snippet"
        
        Req.Test.json(conn, %{"items" => []})
      end)

      assert {:ok, %{"items" => []}} = Client.get("/channels", [part: "snippet"], config)
    end

    test "makes a GET request with OAuth access token" do
      config = %Client.Config{access_token: "oauth_token"}

      Req.Test.expect(Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/liveBroadcasts"
        
        assert ["Bearer oauth_token"] = Plug.Conn.get_req_header(conn, "authorization")
        
        Req.Test.json(conn, %{"items" => []})
      end)

      assert {:ok, %{"items" => []}} = Client.get("/liveBroadcasts", [], config)
    end
  end

  describe "post/4" do
    test "makes a POST request", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts"
        
        {:ok, body, _} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"snippet" => %{"title" => "Test"}}
        
        Req.Test.json(conn, %{"id" => "123"})
      end)

      assert {:ok, %{"id" => "123"}} = Client.post("/liveBroadcasts", %{"snippet" => %{"title" => "Test"}}, [], config)
    end

    test "respects dry_run flag" do
      config = %Client.Config{dry_run: true}
      
      assert {:ok, %{dry_run: true, path: "/liveBroadcasts"}} = Client.post("/liveBroadcasts", %{"snippet" => %{"title" => "Test"}}, [], config)
    end
  end
end
