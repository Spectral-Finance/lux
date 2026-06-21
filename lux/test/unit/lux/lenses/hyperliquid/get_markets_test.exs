defmodule Lux.Lenses.Hyperliquid.GetMarketsTest do
  @moduledoc """
  Test suite for the GetMarkets lens.
  Tests verify:
  - Successful market data fetching and transformation
  - Schema validation
  - Error handling
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Hyperliquid.GetMarkets

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches and transforms market data" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "universe" => [
              %{"name" => "ETH", "szDecimals" => 4, "maxLeverage" => 50},
              %{"name" => "BTC", "szDecimals" => 5, "maxLeverage" => 100}
            ]
          },
          [
            %{
              "funding" => "0.0001",
              "openInterest" => "500000.0",
              "prevDayPx" => "2750.0",
              "dayNtlVlm" => "50000000.0",
              "premium" => "0.0002",
              "oraclePx" => "2799.5",
              "markPx" => "2800.0",
              "midPx" => "2800.5"
            },
            %{
              "funding" => "0.00005",
              "openInterest" => "1000000.0",
              "prevDayPx" => "42000.0",
              "dayNtlVlm" => "200000000.0",
              "premium" => "0.0001",
              "oraclePx" => "42500.0",
              "markPx" => "42505.0",
              "midPx" => "42510.0"
            }
          ]
        ]))
      end)

      assert {:ok, result} = GetMarkets.focus(%{}, %{})
      assert length(result.markets) == 2

      eth_market = Enum.find(result.markets, fn m -> m.name == "ETH" end)
      assert eth_market.sz_decimals == 4
      assert eth_market.max_leverage == 50
      assert eth_market.mark_px == "2800.0"
      assert eth_market.funding == "0.0001"
      assert eth_market.open_interest == "500000.0"

      btc_market = Enum.find(result.markets, fn m -> m.name == "BTC" end)
      assert btc_market.sz_decimals == 5
      assert btc_market.max_leverage == 100
      assert btc_market.mark_px == "42505.0"
    end

    test "handles API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{
          "error" => "Internal server error"
        }))
      end)

      assert {:error, _} = GetMarkets.focus(%{}, %{})
    end
  end

  describe "schema validation" do
    test "validates schema has no required fields" do
      lens = GetMarkets.view()
      assert lens.schema.properties == %{}
    end
  end
end
