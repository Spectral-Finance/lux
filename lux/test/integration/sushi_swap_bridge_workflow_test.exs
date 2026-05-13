defmodule Lux.Integrations.SushiSwapBridgeWorkflowTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.SushiSwap.Bridge
  alias Lux.Integrations.SushiSwap.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "quotes, monitors, and summarizes a cross-chain Sushi workflow" do
    Req.Test.stub(SushiSwapClientMock, fn conn ->
      response =
        case conn.request_path do
          "/quote/v7/1" ->
            query = URI.decode_query(conn.query_string)
            assert query["toChainId"] == "8453"

            %{
              "status" => "Success",
              "amountIn" => "1000",
              "assumedAmountOut" => "985",
              "priceImpact" => 0.01,
              "gasSpent" => 7.5
            }

          "/price/v1/1" ->
            %{"sushi" => 1.5, "usdc" => 1.0}
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(response))
    end)

    assert {:ok, bridge} =
             Bridge.bridge_quote(
               %{
                 from_chain: :ethereum,
                 to_chain: :base,
                 token_in: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
                 token_out: "0x4200000000000000000000000000000000000006",
                 amount: "1000",
                 recipient: "0x0000000000000000000000000000000000000001"
               },
               live: true,
               plug: {Req.Test, SushiSwapClientMock}
             )

    assert bridge.quote.estimated_amount_out == 985.0

    assert {:ok, %{"sushi" => 1.5} = prices} =
             Client.prices(:ethereum, plug: {Req.Test, SushiSwapClientMock})

    dashboard =
      Bridge.dashboard(%{
        routes: [Map.merge(bridge.quote, %{liquidity_usd: 1_000_000, eta_seconds: 600})],
        positions: [
          %{pool: "SUSHI/USDC", token_a: "sushi", amount_a: 10, token_b: "usdc", amount_b: 25}
        ],
        prices: prices,
        transfers: [%{confirmations: 20, eta_seconds: 600, age_seconds: 300}]
      })

    assert dashboard.best_route.alerts == []
    assert dashboard.positions.total_value_usd == 40.0
    assert dashboard.unhealthy_transfers == 0
  end
end
