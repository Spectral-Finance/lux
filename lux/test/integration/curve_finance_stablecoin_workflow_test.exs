defmodule Lux.Integrations.CurveFinanceStablecoinWorkflowTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.CurveFinance.Client
  alias Lux.Integrations.CurveFinance.Stablecoins

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "loads pools, checks yield, plans gauge stake, and builds dashboard" do
    Req.Test.expect(CurveFinanceWorkflowMock, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/getPools/all/ethereum"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "data" => %{
            "poolData" => [
              %{
                "name" => "crvUSD/USDC",
                "address" => "0xpool",
                "lpTokenAddress" => "0xlp",
                "gaugeAddress" => "0xgauge",
                "coins" => [
                  %{"symbol" => "crvUSD", "poolBalance" => "1200000", "usdPrice" => "1"},
                  %{"symbol" => "USDC", "poolBalance" => "1300000", "usdPrice" => "1"}
                ],
                "usdTotal" => "2500000",
                "volumeUSD" => "750000",
                "baseApy" => "0.02",
                "gaugeCrvApy" => "0.03",
                "gaugeRewardsApy" => "0.01",
                "gaugeRewards" => [%{"tokenAddress" => "0xcrv"}],
                "virtualPrice" => "1.01"
              }
            ]
          }
        })
      )
    end)

    assert {:ok, payload} = Client.pools(:ethereum, plug: {Req.Test, CurveFinanceWorkflowMock})
    assert [%{name: "crvUSD/USDC"} = pool] = Stablecoins.pool_analysis(payload)
    assert {:ok, stake_plan} = Stablecoins.gauge_staking_plan(pool, 42)

    dashboard =
      Stablecoins.dashboard(
        %{
          pools: payload,
          positions: [%{pool_address: "0xpool", lp_amount: 42, value_usd: 42.42}],
          allocations: %{crvUSD: 0.55, USDC: 0.45}
        },
        policy: %{target_allocations: %{crvUSD: 0.50, USDC: 0.50}}
      )

    assert stake_plan.gauge_address == "0xgauge"
    assert_in_delta pool.total_apy, 0.06, 0.0001
    assert_in_delta dashboard.positions.weighted_apy, 0.06, 0.0001
    assert dashboard.rebalance.status == :rebalance_required
  end
end
