defmodule Lux.Integrations.DeFiAnalytics.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.DeFiAnalytics
  alias Lux.Integrations.DeFiAnalytics.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "fetches DeFiLlama protocols" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/protocols"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!([%{"name" => "Aave"}]))
    end)

    assert {:ok, [%{"name" => "Aave"}]} =
             Client.protocols(%{plug: {Req.Test, __MODULE__}})
  end

  test "fetches DeFiLlama DEX volume endpoints" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/overview/dexs"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"protocols" => [%{"name" => "Uniswap"}]}))
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/overview/dexs/ethereum"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"protocols" => [%{"name" => "Curve"}]}))
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/summary/dexs/uniswap"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"name" => "Uniswap"}))
    end)

    plug = %{plug: {Req.Test, __MODULE__}}

    assert {:ok, %{"protocols" => [%{"name" => "Uniswap"}]}} = Client.dex_volume_overview(plug)

    assert {:ok, %{"protocols" => [%{"name" => "Curve"}]}} =
             Client.dex_volume_overview_for_chain("ethereum", plug)

    assert {:ok, %{"name" => "Uniswap"}} = Client.dex_volume_summary("uniswap", plug)
  end

  test "fetches Dune latest result with API key" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/v1/query/123/results"
      assert Plug.Conn.get_req_header(conn, "x-dune-api-key") == ["key-1"]

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => %{"rows" => [%{"volume" => 10}]}}))
    end)

    assert {:ok, %{"result" => %{"rows" => [%{"volume" => 10}]}}} =
             Client.dune_latest_result(123, %{api_key: "key-1", plug: {Req.Test, __MODULE__}})
  end

  test "executes Dune SQL" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/v1/sql/execute"
      assert Plug.Conn.get_req_header(conn, "x-dune-api-key") == ["key-1"]

      {:ok, body, _conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "sql" => "select 1",
               "performance" => "medium"
             }

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"execution_id" => "exec-1"}))
    end)

    assert {:ok, %{"execution_id" => "exec-1"}} =
             Client.dune_execute_sql("select 1", %{
               api_key: "key-1",
               performance: "medium",
               plug: {Req.Test, __MODULE__}
             })
  end

  test "normalizes API errors" do
    assert DeFiAnalytics.classify_error(401, %{"error" => "bad key"}) == :invalid_token

    assert DeFiAnalytics.classify_error(429, %{"message" => "slow down"}) ==
             {:rate_limited, "slow down"}
  end
end
