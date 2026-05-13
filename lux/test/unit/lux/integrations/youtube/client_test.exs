defmodule Lux.Integrations.YouTube.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube
  alias Lux.Integrations.YouTube.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "fetches videos with API key auth" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/videos"
      assert conn.query_string =~ "part=snippet%2Cstatistics%2CcontentDetails"
      assert conn.query_string =~ "id=video-1%2Cvideo-2"
      assert conn.query_string =~ "key=key-1"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
    end)

    assert {:ok, %{"items" => []}} =
             Client.videos(["video-1", "video-2"], %{
               api_key: "key-1",
               plug: {Req.Test, __MODULE__}
             })
  end

  test "uses bearer token for analytics reports" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/reports"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token-1"]
      assert conn.query_string =~ "ids=channel%3D%3DMINE"
      assert conn.query_string =~ "metrics=views%2Clikes"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"rows" => [[10, 2]]}))
    end)

    assert {:ok, %{"rows" => [[10, 2]]}} =
             Client.analytics_report(%{
               access_token: "token-1",
               start_date: "2026-01-01",
               end_date: "2026-01-31",
               metrics: ["views", "likes"],
               plug: {Req.Test, __MODULE__}
             })
  end

  test "searches and fetches most popular videos" do
    Req.Test.expect(__MODULE__, 2, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
    end)

    assert {:ok, %{"items" => []}} =
             Client.search("elixir agents", %{api_key: "key-1", plug: {Req.Test, __MODULE__}})

    assert {:ok, %{"items" => []}} =
             Client.most_popular(%{
               api_key: "key-1",
               region_code: "US",
               plug: {Req.Test, __MODULE__}
             })
  end

  test "normalizes API errors" do
    assert YouTube.classify_error(401, %{"error" => %{"message" => "bad"}}) == :invalid_token

    assert YouTube.classify_error(403, %{"error" => %{"message" => "quota"}}) ==
             {:forbidden, "quota"}
  end
end
