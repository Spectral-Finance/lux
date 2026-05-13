defmodule Lux.Integrations.PancakeSwap.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.PancakeSwap
  alias Lux.Integrations.PancakeSwap.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "reports supported chains and subgraphs" do
    assert {:ok, %{id: 56, key: :bsc}} = PancakeSwap.chain("bsc")
    assert {:ok, %{id: 8453, key: :base}} = PancakeSwap.chain(8453)
    assert PancakeSwap.supports_subgraph?(:bsc, :masterchef_v3)
    refute PancakeSwap.supports_subgraph?(:linea, :masterchef_v3)
  end

  test "requires an endpoint for documented subgraphs" do
    assert {:error, {:missing_subgraph_endpoint, :bsc, :masterchef_v3}} =
             PancakeSwap.subgraph_endpoint(:bsc, :masterchef_v3)
  end

  test "runs farm pool query against configured endpoint" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/graphql"

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)

      assert decoded["query"] =~ "PancakeSwapFarmPools"
      assert decoded["variables"] == %{"first" => 25}

      Req.Test.json(conn, %{
        "data" => %{
          "pools" => [
            %{"id" => "1", "pid" => "1", "totalLiquidity" => "1000"}
          ]
        }
      })
    end)

    assert {:ok, %{"data" => %{"pools" => [%{"id" => "1"}]}}} =
             Client.farm_pools(:bsc, %{
               first: 25,
               url: "https://pancake.test/graphql",
               plug: {Req.Test, __MODULE__}
             })
  end

  test "runs position query and normalizes owner" do
    Req.Test.expect(__MODULE__, fn conn ->
      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)

      assert decoded["query"] =~ "PancakeSwapPositions"
      assert decoded["variables"]["owner"] == "0xabc"

      Req.Test.json(conn, %{"data" => %{"userPositionInfos" => []}})
    end)

    assert {:ok, %{"data" => %{"userPositionInfos" => []}}} =
             Client.positions(:bsc, "0xABC", %{
               url: "https://pancake.test/graphql",
               plug: {Req.Test, __MODULE__}
             })
  end

  test "normalizes GraphQL and HTTP errors" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"errors" => [%{"message" => "bad query"}]})
    end)

    assert {:error, {:bad_request, "bad query"}} =
             Client.farm_pools(:bsc, %{
               url: "https://pancake.test/graphql",
               plug: {Req.Test, __MODULE__}
             })

    assert PancakeSwap.classify_error(429, %{"message" => "slow down"}) ==
             {:rate_limited, "slow down"}
  end
end
