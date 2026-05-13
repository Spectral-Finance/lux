defmodule Lux.Integrations.HyperliquidPerpsWorkflowTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.Hyperliquid.Client
  alias Lux.Integrations.Hyperliquid.Perps

  @user "0x0000000000000000000000000000000000000001"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "loads user state, checks risk, and builds trading dashboard" do
    Req.Test.stub(HyperliquidWorkflowMock, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)

      response =
        case payload["type"] do
          "clearinghouseState" ->
            %{
              "crossMarginSummary" => %{
                "accountValue" => "10000",
                "totalNtlPos" => "15000",
                "totalMarginUsed" => "2000"
              },
              "assetPositions" => [
                %{
                  "position" => %{
                    "coin" => "ETH",
                    "szi" => "1",
                    "entryPx" => "2500",
                    "positionValue" => "3000",
                    "unrealizedPnl" => "500",
                    "returnOnEquity" => "0.16",
                    "leverage" => %{"type" => "cross", "value" => 3},
                    "liquidationPx" => "1800"
                  }
                }
              ]
            }

          "allMids" ->
            %{"ETH" => "3000"}

          "openOrders" ->
            [%{"coin" => "ETH", "oid" => 42}]

          "userFills" ->
            [%{"coin" => "ETH", "closedPnl" => "25"}]
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(response))
    end)

    opts = [plug: {Req.Test, HyperliquidWorkflowMock}]

    assert {:ok, user_state} = Client.clearinghouse_state(@user, opts)
    assert {:ok, mids} = Client.all_mids(opts)
    assert {:ok, orders} = Client.open_orders(@user, opts)
    assert {:ok, fills} = Client.user_fills(@user, opts)

    assert {:ok, decision} =
             Perps.risk_check(user_state, mids, %{
               coin: "ETH",
               is_buy: true,
               sz: 0.1,
               limit_px: 3000
             })

    dashboard =
      Perps.dashboard(%{
        user_state: user_state,
        mids: mids,
        fills: fills,
        open_orders: orders
      })

    assert decision.decision == :approved
    assert dashboard.margin.leverage == 1.5
    assert dashboard.pnl.total_pnl == 525.0
    assert dashboard.open_order_count == 1
    assert dashboard.liquidation.status == :healthy
  end
end
