defmodule Lux.Integrations.CurveFinanceTest do
  use ExUnit.Case, async: false

  alias Lux.Integrations.CurveFinance

  @annual_crv_emission 200_000_000
  @pool_fixture %{
    "id" => "pool-1",
    "address" => "0xpool",
    "name" => "3pool",
    "type" => "stable",
    "fee" => "0.0004",
    "totalValueLockedUSD" => "500000000",
    "volumeUSD" => "10000000",
    "coins" => [
      %{"address" => "0xa", "symbol" => "USDC", "decimals" => "6"},
      %{"address" => "0xb", "symbol" => "USDT", "decimals" => "6"}
    ]
  }

  setup do
    previous = Application.get_env(:lux, CurveFinance)

    Application.put_env(:lux, CurveFinance,
      subgraph_url: "https://curve.test/graphql",
      price_url: "https://curve.test/price",
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    Req.Test.verify_on_exit!()

    on_exit(fn ->
      if previous,
        do: Application.put_env(:lux, CurveFinance, previous),
        else: Application.delete_env(:lux, CurveFinance)
    end)

    :ok
  end

  test "uses an explicitly configured data source" do
    assert CurveFinance.subgraph_url() == "https://curve.test/graphql"
  end

  test "requires a configured subgraph instead of using the retired hosted-service URL" do
    Application.delete_env(:lux, CurveFinance)
    previous = System.get_env("CURVE_SUBGRAPH_URL")
    System.delete_env("CURVE_SUBGRAPH_URL")

    on_exit(fn ->
      if previous, do: System.put_env("CURVE_SUBGRAPH_URL", previous)
    end)

    assert_raise ArgumentError, ~r/Curve subgraph is not configured/, fn ->
      CurveFinance.subgraph_url()
    end
  end

  test "fetch_pools sends GraphQL to the injected adapter and parses the fixture" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/graphql"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body)["query"] =~ "pools(first: 100)"
      Req.Test.json(conn, %{"data" => %{"pools" => [@pool_fixture]}})
    end)

    assert {:ok, [pool]} = CurveFinance.fetch_pools()
    assert pool.id == "pool-1"
    assert pool.tvl_usd == 500_000_000.0
    assert Enum.map(pool.coins, & &1.symbol) == ["USDC", "USDT"]
  end

  test "fetch_pools exposes fixture-backed GraphQL errors" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"errors" => [%{"message" => "schema mismatch"}]})
    end)

    assert {:error, {:graphql_errors, [%{"message" => "schema mismatch"}]}} =
             CurveFinance.fetch_pools()
  end

  test "fetch_gauges sends the requested pool id and parses the fixture" do
    Req.Test.expect(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body)["query"] =~ ~s(pool: "pool-1")

      Req.Test.json(conn, %{
        "data" => %{
          "gauges" => [
            %{
              "id" => "gauge-1",
              "pool" => %{"id" => "pool-1"},
              "workingSupply" => "100",
              "supply" => "200",
              "voteAmount" => "50"
            }
          ]
        }
      })
    end)

    assert {:ok, [gauge]} = CurveFinance.fetch_gauges("pool-1")

    assert gauge == %{
             id: "gauge-1",
             pool_id: "pool-1",
             working_supply: "100",
             supply: "200",
             vote_amount: "50"
           }
  end

  test "fetch_crv_price uses the injected price adapter" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/price"
      assert conn.query_string =~ "curve-dao-token"
      Req.Test.json(conn, %{"curve-dao-token" => %{"usd" => 0.6}})
    end)

    assert {:ok, 0.6} = CurveFinance.fetch_crv_price()
  end

  test "pure analysis helpers select pools and calculate estimates" do
    pools = [
      %{id: "low", coins: [%{symbol: "USDC"}, %{symbol: "USDT"}], tvl_usd: 1_000_000},
      %{id: "high", coins: [%{symbol: "USDC"}, %{symbol: "USDT"}], tvl_usd: 500_000_000}
    ]

    assert {:ok, %{id: "high"}} = CurveFinance.select_pool("usdc", "usdt", pools)
    assert CurveFinance.estimate_slippage(10_000, 500_000_000) == 0.00002

    expected = @annual_crv_emission * 0.005 * 0.6 / 500_000_000
    assert_in_delta CurveFinance.estimate_crv_apy(0.005, 0.6, 500_000_000), expected, 1.0e-10

    assert CurveFinance.rebalance_threshold(0.0004, 0.001) == 0.002
    assert CurveFinance.should_rebalance(0.6, 0.5, 0.05) == :rebalance
    assert CurveFinance.should_rebalance(0.51, 0.5, 0.05) == :hold
  end
end
